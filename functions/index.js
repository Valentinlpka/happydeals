const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { log } = require("firebase-functions/logger");
const stripe = require("stripe")(functions.config().stripe.secret_key);
const stripeWebhooks = functions.config().stripe.webhooks || {};
const nodemailer = require("nodemailer");
// Configuration du transporteur email
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: functions.config().gmail.email,
    pass: functions.config().gmail.password,
  },
});

// Ajoutez ces logs
console.log("Email configuration:", {
  user: functions.config().gmail.email,
  configured: !!functions.config().gmail.password,
});

admin.initializeApp();

exports.createStripeCheckoutSession = functions.firestore
  .document("users/{userId}/checkout_sessions/{docId}")
  .onCreate(async (snap, context) => {
    try {
      const { price, success_url, cancel_url } = snap.data();

      // Récupérer ou créer le client Stripe
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(context.params.userId)
        .get();
      const user = userDoc.data();
      let customerId = user.stripeCustomerId;

      if (!customerId) {
        const customer = await stripe.customers.create({
          email: user.email,
          metadata: { firebaseUID: context.params.userId },
        });
        customerId = customer.id;
        await userDoc.ref.update({ stripeCustomerId: customerId });
      }

      // Créer la session Stripe
      const session = await stripe.checkout.sessions.create({
        customer: customerId,
        payment_method_types: ["card"],
        line_items: [
          {
            price: price,
            quantity: 1,
          },
        ],
        mode: "subscription",
        success_url: success_url,
        cancel_url: cancel_url,
      });

      // Mettre à jour le document avec l'ID de session
      await snap.ref.update({
        sessionId: session.id,
        created: admin.firestore.FieldValue.serverTimestamp(),
      });

      return session;
    } catch (error) {
      console.error("Error:", error);
      throw error;
    }
  });

exports.createPortalSession = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  try {
    console.log("Début createPortalSession pour:", context.auth.uid);
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(context.auth.uid)
      .get();
    const userData = userDoc.data();
    console.log("Données utilisateur:", userData);

    if (!userData?.stripeCustomerId) {
      console.log("Pas de stripeCustomerId trouvé");
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Aucun client Stripe associé."
      );
    }

    // Utiliser l'URL de retour fournie par le client ou une URL par défaut
    const returnUrl = data.returnUrl || "https://up-pro.vercel.app/dashboard";

    const session = await stripe.billingPortal.sessions.create({
      customer: userData.stripeCustomerId,
      return_url: returnUrl,
    });

    console.log("Session portail créée:", session.url);
    return { url: session.url };
  } catch (error) {
    console.error("Erreur création portal session:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Gestion des abonnements Stripe
exports.createCheckoutSession = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "L'utilisateur doit être authentifié."
      );
    }

    try {
      const { priceId, planName, currentSubscriptionId } = data;
      const userId = context.auth.uid;

      // Définir l'URL de base
      const baseUrl =
        process.env.NODE_ENV === "development"
          ? "http://localhost:3000"
          : "https://up-pro.vercel.app";

      // Récupérer ou créer le client Stripe
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .get();
      const userData = userDoc.data();
      let customerId = userData.stripeCustomerId;

      if (!customerId) {
        const customer = await stripe.customers.create({
          email: userData.email,
          metadata: { firebaseUID: userId },
          name: userData.firstName + " " + userData.lastName,
        });
        customerId = customer.id;
        await userDoc.ref.update({ stripeCustomerId: customer.id });
      }

      // Configuration de base de la session
      const sessionConfig = {
        customer: customerId,
        payment_method_types: ["card"],
        line_items: [
          {
            price: priceId,
            quantity: 1,
          },
        ],
        mode: "subscription",
        success_url: `${baseUrl}/plans/success`,
        cancel_url: `${baseUrl}/plans`,
        metadata: {
          firebaseUID: userId,
          planName: planName,
        },
        allow_promotion_codes: true,
      };

      // Si c'est une mise à niveau/rétrogradation
      if (currentSubscriptionId) {
        sessionConfig.subscription_data = {
          metadata: {
            previous_subscription: currentSubscriptionId,
          },
        };
      }

      const session = await stripe.checkout.sessions.create(sessionConfig);
      return { sessionId: session.id };
    } catch (error) {
      console.error("Erreur création session:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

// Webhook Stripe pour gérer les événements d'abonnement
exports.stripeWebhook = functions.https.onRequest(async (request, response) => {
  const sig = request.headers["stripe-signature"];
  const webhookSecret = functions.config().stripe.webhook_secret;
  let event;

  try {
    event = stripe.webhooks.constructEvent(request.rawBody, sig, webhookSecret);
  } catch (err) {
    console.error("Webhook Error:", err.message);
    return response.status(400).send(`Webhook Error: ${err.message}`);
  }

  try {
    switch (event.type) {
      case "checkout.session.completed":
        await handleCheckoutSessionCompleted(event.data.object);
        break;
      case "invoice.paid":
        await handleInvoicePaid(event.data.object);
        break;
      case "invoice.payment_failed":
        await handleInvoicePaymentFailed(event.data.object);
        break;
      case "customer.subscription.deleted":
        await handleSubscriptionDeleted(event.data.object);
        break;
      case "customer.subscription.updated":
        await handleSubscriptionUpdated(event.data.object);
        break;
    }

    response.json({ received: true });
  } catch (error) {
    console.error("Error processing webhook:", error);
    response.status(500).send("Webhook processing failed");
  }
});

// Gestion des événements de paiement Stripe
async function handleCheckoutSessionCompleted(session) {
  const { firebaseUID, planName } = session.metadata;
  const subscriptionId = session.subscription;

  try {
    // Récupérer les détails de l'abonnement
    const subscription = await stripe.subscriptions.retrieve(subscriptionId);

    // Si c'est une mise à niveau/rétrogradation
    if (session.subscription_data?.metadata?.previous_subscription) {
      const previousSubscriptionId =
        session.subscription_data.metadata.previous_subscription;

      // Annuler l'ancien abonnement à la fin de la période
      await stripe.subscriptions.update(previousSubscriptionId, {
        cancel_at_period_end: true,
        metadata: {
          replaced_by: subscriptionId,
        },
      });
    }

    // Mettre à jour Firestore
    const userRef = admin.firestore().collection("users").doc(firebaseUID);
    await userRef.update({
      subscriptionId: subscriptionId,
      subscriptionStatus: subscription.status,
      priceId: subscription.items.data[0].price.id,
      planName: planName,
      subscriptionPeriodEnd: admin.firestore.Timestamp.fromDate(
        new Date(subscription.current_period_end * 1000)
      ),
      subscriptionRenewal: true,
    });
  } catch (error) {
    console.error(
      "Erreur lors du traitement de checkout.session.completed:",
      error
    );
    throw error;
  }
}

async function handleInvoicePaid(invoice) {
  if (invoice.subscription) {
    const subscription = await stripe.subscriptions.retrieve(
      invoice.subscription
    );
    const customer = await stripe.customers.retrieve(invoice.customer);

    // Récupérer le planName depuis les métadonnées de la subscription
    const planName = subscription.metadata.planName;

    await admin
      .firestore()
      .collection("users")
      .doc(customer.metadata.firebaseUID)
      .update({
        subscriptionStatus: subscription.status,
        subscriptionPeriodEnd: admin.firestore.Timestamp.fromMillis(
          subscription.current_period_end * 1000
        ),
        planName: planName, // Ajouter le planName
      });
  }
}

async function handleInvoicePaymentFailed(invoice) {
  if (invoice.subscription) {
    const customer = await stripe.customers.retrieve(invoice.customer);

    await admin
      .firestore()
      .collection("users")
      .doc(customer.metadata.firebaseUID)
      .update({
        subscriptionStatus: "past_due",
      });
  }
}

async function handleSubscriptionDeleted(subscription) {
  const customer = await stripe.customers.retrieve(subscription.customer);

  await admin
    .firestore()
    .collection("users")
    .doc(customer.metadata.firebaseUID)
    .update({
      subscriptionId: admin.firestore.FieldValue.delete(),
      subscriptionStatus: "canceled",
      planName: admin.firestore.FieldValue.delete(),
      priceId: admin.firestore.FieldValue.delete(),
      subscriptionPeriodEnd: admin.firestore.FieldValue.delete(),
    });
}

async function handleSubscriptionUpdated(subscription) {
  try {
    const customer = await stripe.customers.retrieve(subscription.customer);
    const firebaseUID = customer.metadata.firebaseUID;

    // Récupérer le planName depuis les métadonnées
    const planName = subscription.metadata.planName;

    if (!firebaseUID) {
      console.error("No Firebase UID found for customer:", customer.id);
      return;
    }

    const subscriptionRenewal = subscription.cancel_at_period_end === false;

    await admin
      .firestore()
      .collection("users")
      .doc(firebaseUID)
      .update({
        subscriptionId: subscription.id,
        subscriptionStatus: subscription.status,
        priceId: subscription.items.data[0].price.id,
        planName: planName, // Ajouter le planName
        subscriptionPeriodEnd: admin.firestore.Timestamp.fromMillis(
          subscription.current_period_end * 1000
        ),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        // Ajout du statut de renouvellement automatique
        subscriptionRenewal: subscriptionRenewal,
        // Ajout de la date de fin si le renouvellement est désactivé
        cancelAt: subscription.cancel_at
          ? admin.firestore.Timestamp.fromMillis(subscription.cancel_at * 1000)
          : null,
        subscriptionPlan: {
          interval: subscription.items.data[0].price.recurring.interval,
          amount: subscription.items.data[0].price.unit_amount / 100,
          currency: subscription.items.data[0].price.currency,
        },
      });

    console.log(`Updated subscription for user ${firebaseUID}`, {
      subscriptionRenewal,
      cancelAt: subscription.cancel_at || "Not cancelled",
    });
  } catch (error) {
    console.error("Error handling subscription update:", error);
    throw error;
  }
}

// Annuler Abonnement Stripe pour les Pro.
exports.cancelSubscription = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  try {
    const { subscriptionId } = data;

    // Annuler l'abonnement immédiatement
    await stripe.subscriptions.cancel(subscriptionId, {
      prorate: true,
    });

    return { success: true };
  } catch (error) {
    console.error("Error canceling subscription:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Création d'un compte Connect
exports.createConnectAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated."
    );
  }
  try {
    // Récupérer les informations de l'utilisateur depuis Firestore
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(context.auth.uid)
      .get();
    const userData = userDoc.data();

    if (!userData || !userData.email) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Informations utilisateur incomplètes."
      );
    }

    // Créer le compte Stripe Connect
    const account = await stripe.accounts.create({
      type: "express",
      country: "FR",
      email: userData.email,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
    });

    // Mettre à jour l'utilisateur avec l'ID du compte Stripe
    await admin.firestore().collection("users").doc(context.auth.uid).update({
      stripeAccountId: account.id,
    });

    // Créer l'entreprise dans la collection companys
    await admin
      .firestore()
      .collection("companys")
      .doc(context.auth.uid)
      .update({
        sellerId: account.id,
      });

    // Créer le lien d'onboarding
    const accountLink = await stripe.accountLinks.create({
      account: account.id,
      refresh_url: `https://up-pro.vercel.app/dashboard`,
      return_url: `https://up-pro.vercel.app/dashboard`,
      type: "account_onboarding",
    });

    return { url: accountLink.url };
  } catch (error) {
    console.error("Erreur lors de la création du compte Connect:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Création d'un lien d'onboarding
exports.createAccountLink = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated."
    );
  }

  const user = await admin
    .firestore()
    .collection("users")
    .doc(context.auth.uid)
    .get();
  const accountId = user.data().stripeAccountId;

  const accountLink = await stripe.accountLinks.create({
    account: accountId,
    refresh_url: `https://up-pro.vercel.app/login`,
    return_url: `https://up-pro.vercel.app/dashboard`,
    type: "account_onboarding",
  });

  return { url: accountLink.url };
});

// Demande d'un paiement de la part d'un pro
exports.requestPayout = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  const { amount, companyId } = data;
  const userUid = context.auth.uid;

  try {
    // Vérifier que l'utilisateur est bien associé à l'entreprise
    const companyDoc = await admin
      .firestore()
      .collection("companys")
      .doc(companyId)
      .get();

    if (!companyDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Entreprise non trouvée"
      );
    }

    const companyData = companyDoc.data();

    // Vérifier que l'utilisateur est bien le propriétaire de l'entreprise
    if (companyDoc.id !== userUid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Vous n'avez pas les droits pour cette entreprise"
      );
    }

    // Vérifier que le montant demandé ne dépasse pas le solde disponible
    if (amount > companyData.availableBalance) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Montant demandé supérieur au solde disponible"
      );
    }

    // Vérifier que le compte Stripe est bien configuré
    if (!companyData.sellerId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Le compte Stripe de l'entreprise n'est pas configuré"
      );
    }

    // Créer un transfert Stripe
    const transfer = await stripe.transfers.create({
      amount: Math.round(amount * 100), // Convertir en centimes
      currency: "eur",
      destination: companyData.sellerId,
    });

    // Mettre à jour le solde de l'entreprise
    await admin
      .firestore()
      .collection("companys")
      .doc(companyId)
      .update({
        availableBalance: admin.firestore.FieldValue.increment(-amount),
      });

    // Enregistrer la demande de virement
    await admin.firestore().collection("payouts").add({
      companyId: companyId,
      amount: amount,
      status: "completed",
      stripeTransferId: transfer.id,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, transferId: transfer.id };
  } catch (error) {
    console.error("Erreur lors de la demande de virement:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Création d'un produit avec variantes
exports.createProduct = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  try {
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(context.auth.uid)
      .get();

    if (!userDoc.exists || !userDoc.data().stripeAccountId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "L'utilisateur n'a pas de compte Stripe associé"
      );
    }

    const stripeAccountId = userDoc.data().stripeAccountId;

    // Créer le produit principal dans Stripe
    const stripeProduct = await stripe.products.create(
      {
        name: data.name,
        description: data.description || "",
        metadata: {
          categoryId: data.categoryId,
          tva: data.tva.toString(),
          categoryPath: JSON.stringify(data.categoryPath),
        },
      },
      {
        stripeAccount: stripeAccountId,
      }
    );

    // Créer les variantes dans Stripe
    const variantsWithStripeData = await Promise.all(
      data.variants.map(async (variant) => {
        const variantName = Object.entries(variant.attributes)
          .map(([key, value]) => `${key}: ${value}`)
          .join(", ");

        const stripePrice = await stripe.prices.create(
          {
            product: stripeProduct.id,
            unit_amount: Math.round(variant.price * 100),
            currency: "eur",
            metadata: {
              variantId: variant.id,
              attributes: JSON.stringify(variant.attributes),
              stock: variant.stock.toString(),
              tva: data.tva.toString(),
              priceTTC: variant.price.toString(),
            },
          },
          {
            stripeAccount: stripeAccountId,
          }
        );

        return {
          ...variant,
          stripePriceId: stripePrice.id,
        };
      })
    );

    // Créer le document dans Firestore
    const productRef = admin.firestore().collection("products").doc();
    await productRef.set({
      id: productRef.id,
      name: data.name,
      description: data.description,
      basePrice: data.basePrice, //Prix TTC
      categoryId: data.categoryId,
      categoryPath: data.categoryPath,
      tva: data.tva,
      isActive: true,
      merchantId: stripeAccountId,
      sellerId: context.auth.uid,
      stripeProductId: stripeProduct.id,
      technicalDetails: data.technicalDetails || [], // Ajout des détails techniques
      keywords: data.keywords || [], // Ajout des tags
      variants: variantsWithStripeData,
      pickupType: data.pickupType || "company", // Type de retrait
      pickupAddress: data.pickupAddress || "", // Adresse de retrait
      pickupPostalCode: data.pickupPostalCode || "", // Code postal
      pickupCity: data.pickupCity || "", // Ville
      pickupLatitude: data.pickupLatitude || 0, // Latitude
      pickupLongitude: data.pickupLongitude || 0, // Longitude
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      productId: productRef.id,
      stripeProductId: stripeProduct.id,
    };
  } catch (error) {
    console.error("Erreur:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Impossible de créer le produit: ${error.message}`
    );
  }
});

// Mise à jour d'un produit avec variantes
exports.updateProduct = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  try {
    const productRef = admin.firestore().collection("products").doc(data.id);
    const product = await productRef.get();

    if (!product.exists) {
      throw new functions.https.HttpsError("not-found", "Produit non trouvé");
    }

    // Mettre à jour le produit dans Stripe
    await stripe.products.update(
      data.stripeProductId,
      {
        name: data.name,
        description: data.description,
        metadata: {
          categoryId: data.categoryId,
          tva: data.tva.toString(),
        },
      },
      {
        stripeAccount: data.merchantId,
      }
    );

    // Gérer les variantes
    const existingVariants = product.data().variants || [];
    const updatedVariants = await Promise.all(
      data.variants.map(async (variant) => {
        const existingVariant = existingVariants.find(
          (v) => v.id === variant.id
        );

        if (existingVariant?.stripePriceId) {
          // Mettre à jour le prix existant
          await stripe.prices.update(
            existingVariant.stripePriceId,
            {
              active: false,
            },
            {
              stripeAccount: data.merchantId,
            }
          );
        }

        // Créer un nouveau prix pour la variante
        const stripePrice = await stripe.prices.create(
          {
            product: data.stripeProductId,
            unit_amount: Math.round(variant.price * 100),
            currency: "eur",
            metadata: {
              variantId: variant.id,
              attributes: JSON.stringify(variant.attributes),
              stock: variant.stock.toString(),
              tva: data.tva.toString(),
              priceTTC: variant.price.toString(),
            },
          },
          {
            stripeAccount: data.merchantId,
          }
        );

        return {
          ...variant,
          stripePriceId: stripePrice.id,
        };
      })
    );

    // Mettre à jour Firestore
    await productRef.update({
      name: data.name,
      description: data.description,
      basePrice: data.basePrice,
      categoryId: data.categoryId,
      variants: updatedVariants,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (error) {
    console.error("Erreur:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Impossible de mettre à jour le produit: ${error.message}`
    );
  }
});

// Fonction pour mettre à jour le stock
exports.updateStock = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  const { productId, newStock } = data;

  try {
    const productRef = admin.firestore().collection("products").doc(productId);
    const product = await productRef.get();

    if (!product.exists) {
      throw new functions.https.HttpsError("not-found", "Produit non trouvé");
    }

    await productRef.update({ stock: newStock });

    // Mettre à jour les métadonnées du produit dans Stripe
    await stripe.products.update(
      product.data().stripeProductId,
      {
        metadata: { stock: newStock.toString() },
      },
      {
        stripeAccount: product.data().merchantId,
      }
    );

    return { success: true, newStock };
  } catch (error) {
    console.error("Erreur lors de la mise à jour du stock:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Impossible de mettre à jour le stock"
    );
  }
});

// Suppression d'un article
exports.deleteProduct = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  const { productId } = data;

  try {
    const productRef = admin.firestore().collection("products").doc(productId);
    const product = await productRef.get();

    if (!product.exists) {
      throw new functions.https.HttpsError("not-found", "Produit non trouvé");
    }

    // Suppression dans Stripe
    await stripe.products.del(product.data().stripeProductId);

    // Suppression dans Firestore (ou marquer comme supprimé)
    await productRef.delete({});

    return { success: true, productId };
  } catch (error) {
    console.error("Erreur lors de la suppression du produit:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Impossible de supprimer le produit"
    );
  }
});

// Mise à jour du statut d'une commande
exports.updateOrderStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  const { orderId, newStatus } = data;

  try {
    const orderRef = admin.firestore().collection("orders").doc(orderId);
    const order = await orderRef.get();

    if (!order.exists) {
      throw new functions.https.HttpsError("not-found", "Commande non trouvée");
    }

    const orderData = order.data();

    // Vérifier que le statut est valide
    const validStatuses = [
      "payée",
      "en préparation",
      "prête à être retirée",
      "completed",
    ];
    if (!validStatuses.includes(newStatus)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Statut invalide"
      );
    }

    // Si le nouveau statut est "prête à être retirée", générer un code de retrait
    let pickupCode = null;
    if (newStatus === "prête à être retirée") {
      pickupCode = Math.random().toString(36).substr(2, 6).toUpperCase();
    }

    // Mise à jour du statut
    await orderRef.update({
      status: newStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      pickupCode: pickupCode,
    });

    // Créer une notification en fonction du nouveau statut
    const notificationRef = admin.firestore().collection("notifications").doc();
    let notificationData = {
      userId: orderData.userId,
      targetId: orderId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    };

    let notificationTitle = "";
    let notificationBody = "";

    switch (newStatus) {
      case "prête à être retirée":
        notificationData = {
          ...notificationData,
          type: "order",
          title: "Commande prête",
          message: `Votre commande #${orderId} est prête à être retirée${
            pickupCode ? `. Code de retrait : ${pickupCode}` : ""
          }`,
          targetId: orderId,
        };
        notificationTitle = "Commande prête";
        notificationBody = notificationData.message;
        break;
      case "completed":
        notificationData = {
          ...notificationData,
          type: "order",
          title: "Commande terminée",
          message: `Votre commande #${orderId} est maintenant terminée`,
          targetId: orderId,
        };
        notificationTitle = "Commande terminée";
        notificationBody = notificationData.message;
        break;
    }

    // Envoyer la notification seulement pour ces statuts
    if (["prête à être retirée", "completed"].includes(newStatus)) {
      // 1. Sauvegarder dans Firestore
      await notificationRef.set(notificationData);

      // 2. Récupérer le token FCM de l'utilisateur
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(orderData.userId)
        .get();

      const fcmToken = userDoc.data()?.fcmToken;

      // 3. Envoyer la notification push si le token existe
      if (fcmToken) {
        const message = {
          notification: {
            title: notificationTitle,
            body: notificationBody,
          },
          data: {
            type: "order",
            targetId: orderId,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          token: fcmToken,
        };

        try {
          await admin.messaging().send(message);
          console.log("Notification push envoyée avec succès");
        } catch (error) {
          console.error(
            "Erreur lors de l'envoi de la notification push:",
            error
          );
        }
      }
    }

    return { success: true, orderId, newStatus, pickupCode };
  } catch (error) {
    console.error(
      "Erreur lors de la mise à jour du statut de la commande:",
      error
    );
    throw new functions.https.HttpsError(
      "internal",
      "Impossible de mettre à jour le statut de la commande"
    );
  }
});

// Confirmation de la réception d'un deal Express
exports.confirmDealExpressPickup = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "L'utilisateur doit être authentifié."
      );
    }

    const { reservationId, pickupCode } = data;

    try {
      const reservationRef = admin
        .firestore()
        .collection("reservations")
        .doc(reservationId);
      const reservation = await reservationRef.get();

      if (!reservation.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Réservation non trouvée"
        );
      }

      const reservationData = reservation.data();

      if (reservationData.status !== "prête à être retirée") {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "La réservation n'est pas prête à être retirée"
        );
      }

      if (reservationData.validationCode !== pickupCode) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Code de retrait invalide"
        );
      }

      // Confirmation de la réception
      await reservationRef.update({
        status: "completed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        // Mettre à jour le stock du produit si nécessaire
      });

      return {
        success: true,
        reservationId,
        message: "Réservation confirmée avec succès",
      };
    } catch (error) {
      console.error(
        "Erreur lors de la confirmation de la réservation Deal Express:",
        error
      );
      throw new functions.https.HttpsError(
        "internal",
        error.message || "Impossible de confirmer la réservation"
      );
    }
  }
);

// Confirmation de la réception de la commande
exports.confirmOrderPickup = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  const { orderId, pickupCode } = data;

  try {
    const orderRef = admin.firestore().collection("orders").doc(orderId);
    const order = await orderRef.get();

    if (!order.exists) {
      throw new functions.https.HttpsError("not-found", "Commande non trouvée");
    }

    if (order.data().status !== "prête à être retirée") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "La commande n'est pas prête à être retirée"
      );
    }

    if (order.data().pickupCode !== pickupCode) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Code de retrait invalide"
      );
    }

    // Confirmation de la réception
    await orderRef.update({
      status: "completed",
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, orderId };
  } catch (error) {
    console.error(
      "Erreur lors de la confirmation de la réception de la commande:",
      error
    );
    throw new functions.https.HttpsError(
      "internal",
      "Impossible de confirmer la réception de la commande"
    );
  }
});

exports.getStripeDashboardLink = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "L'utilisateur doit être authentifié."
      );
    }

    try {
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(context.auth.uid)
        .get();
      const stripeAccountId = userDoc.data().stripeAccountId;

      if (!stripeAccountId) {
        throw new Error("L'utilisateur n'a pas de compte Stripe associé");
      }

      const loginLink = await stripe.accounts.createLoginLink(stripeAccountId);

      return { url: loginLink.url };
    } catch (error) {
      console.error(
        "Erreur lors de la création du lien de connexion Stripe:",
        error
      );
      throw new functions.https.HttpsError(
        "internal",
        "Impossible de créer le lien de connexion Stripe"
      );
    }
  }
);

exports.testStripeConnection = functions.https.onCall(async (data, context) => {
  try {
    // Tenter de récupérer les détails du compte Stripe
    const account = await stripe.account.retrieve();
    console.log("Connexion Stripe réussie. Détails du compte :", account);
    return {
      success: true,
      message: "Connexion Stripe réussie",
      accountId: account.id,
    };
  } catch (error) {
    console.error("Erreur de connexion Stripe :", error);
    throw new functions.https.HttpsError(
      "internal",
      `Erreur de connexion Stripe : ${error.message}`
    );
  }
});

exports.createStripeCustomer = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  try {
    const user = await admin
      .firestore()
      .collection("users")
      .doc(context.auth.uid)
      .get();
    const userData = user.data();

    if (!userData.stripeCustomerId) {
      const customer = await stripe.customers.create({
        email: userData.email,
        metadata: { firebaseUID: context.auth.uid },
        name: userData.firstName + " " + userData.lastName,
      });

      await admin.firestore().collection("users").doc(context.auth.uid).update({
        stripeCustomerId: customer.id,
      });

      return { customerId: customer.id };
    } else {
      return { customerId: userData.stripeCustomerId };
    }
  } catch (error) {
    console.error("Erreur lors de la création du client Stripe:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Impossible de créer le client Stripe"
    );
  }
});

exports.verifyPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated."
    );
  }

  const { sessionId } = data;

  try {
    const session = await stripe.checkout.sessions.retrieve(sessionId);

    if (session.payment_status === "paid") {
      // Le paiement a réussi
      return { success: true };
    } else {
      // Le paiement n'a pas réussi ou est en attente
      return { success: false };
    }
  } catch (error) {
    console.error("Error verifying payment:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

exports.confirmReservation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  const { dealId, paymentIntentId } = data;

  try {
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    if (paymentIntent.status !== "succeeded") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Le paiement n'a pas été effectué avec succès."
      );
    }

    const dealDoc = await admin
      .firestore()
      .collection("posts")
      .doc(dealId)
      .get();
    const dealData = dealDoc.data();

    if (!dealData) {
      throw new functions.https.HttpsError("not-found", "Deal non trouvé");
    }

    const validationCode = Math.random()
      .toString(36)
      .substr(2, 6)
      .toUpperCase();

    const companyDoc = await admin
      .firestore()
      .collection("companys")
      .doc(dealData.companyId)
      .get();
    const companyData = companyDoc.data();

    const adress = companyData.adress;
    const addressParts = [
      adress.adresse,
      adress.code_postal,
      adress.ville,
      adress.pays,
    ].filter(Boolean);

    const appliedPrice =
      dealData.hasActiveHappyDeal && dealData.discountedPrice
        ? dealData.discountedPrice
        : dealData.price;

    const reservation = {
      buyerId: context.auth.uid,
      postId: dealId,
      companyId: dealData.companyId,
      basketType: dealData.basketType,
      price: appliedPrice,
      originalPrice: dealData.price,
      discountAmount: dealData.hasActiveHappyDeal
        ? dealData.price - appliedPrice
        : 0,
      pickupDate: dealData.pickupTime,
      isValidated: false,
      paymentIntentId: paymentIntentId,
      validationCode: validationCode,
      quantity: 1,
      companyName: companyData.name,
      pickupAddress: addressParts.join(", "),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };

    const reservationRef = await admin
      .firestore()
      .collection("reservations")
      .add(reservation);

    await admin
      .firestore()
      .collection("posts")
      .doc(dealId)
      .update({
        basketCount: admin.firestore.FieldValue.increment(-1),
      });

    return {
      success: true,
      reservationId: reservationRef.id,
      validationCode: validationCode,
    };
  } catch (error) {
    console.error("Erreur lors de la confirmation de la réservation:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Cloud Functions
exports.createExpressDeal = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  try {
    console.log("Création d'un Express Deal avec les données:", data);
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(context.auth.uid)
      .get();

    const stripeAccountId = userDoc.data().stripeAccountId;
    if (!stripeAccountId) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Compte Stripe non configuré"
      );
    }

    // Création du produit sur Stripe
    const product = await stripe.products.create(
      {
        name: data.title,
        description: data.content,
        metadata: {
          type: "express_deal",
          basketCount: data.basketCount.toString(),
          pickupTimes: JSON.stringify(data.pickupTimes),
        },
      },
      {
        stripeAccount: stripeAccountId,
      }
    );

    // Création du prix sur Stripe
    const price = await stripe.prices.create(
      {
        product: product.id,
        unit_amount: data.price * 100,
        currency: "eur",
      },
      {
        stripeAccount: stripeAccountId,
      }
    );

    return {
      success: true,
      stripeProductId: product.id,
      stripePriceId: price.id,
    };
  } catch (error) {
    console.error("Erreur lors de la création de l'Express Deal:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

exports.updateExpressDeal = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  try {
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(context.auth.uid)
      .get();

    const stripeAccountId = userDoc.data().stripeAccountId;

    // Mise à jour du produit sur Stripe
    await stripe.products.update(
      data.stripeProductId,
      {
        name: data.title,
        description: data.content,
        metadata: {
          basketCount: data.basketCount.toString(),
          pickupTimes: JSON.stringify(data.pickupTimes),
        },
      },
      {
        stripeAccount: stripeAccountId,
      }
    );

    // Création d'un nouveau prix si le prix a changé
    if (data.priceChanged) {
      // Désactiver l'ancien prix
      await stripe.prices.update(
        data.stripePriceId,
        { active: false },
        { stripeAccount: stripeAccountId }
      );

      // Créer un nouveau prix
      const newPrice = await stripe.prices.create(
        {
          product: data.stripeProductId,
          unit_amount: data.price * 100,
          currency: "eur",
        },
        { stripeAccount: stripeAccountId }
      );

      return {
        success: true,
        stripePriceId: newPrice.id,
      };
    }

    return { success: true };
  } catch (error) {
    console.error("Erreur lors de la mise à jour de l'Express Deal:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

exports.deleteExpressDeal = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  try {
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(context.auth.uid)
      .get();

    const stripeAccountId = userDoc.data().stripeAccountId;

    // Archiver le produit sur Stripe
    await stripe.products.update(
      data.stripeProductId,
      { active: false },
      { stripeAccount: stripeAccountId }
    );

    // Désactiver les prix associés
    const prices = await stripe.prices.list(
      { product: data.stripeProductId },
      { stripeAccount: stripeAccountId }
    );

    for (const price of prices.data) {
      await stripe.prices.update(
        price.id,
        { active: false },
        { stripeAccount: stripeAccountId }
      );
    }

    return { success: true };
  } catch (error) {
    console.error("Erreur lors de la suppression de l'Express Deal:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Dans votre index.js de Cloud Functions
exports.createService = functions.https.onCall(async (data, context) => {
  console.log("Début de la fonction createService");
  console.log("Données reçues:", JSON.stringify(data));

  if (!context.auth) {
    console.log("Erreur: Utilisateur non authentifié");
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  try {
    // Récupération des données utilisateur et du compte Stripe
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(context.auth.uid)
      .get();

    if (!userDoc.exists) {
      console.log("Erreur: Document utilisateur non trouvé");
      throw new functions.https.HttpsError(
        "not-found",
        "Document utilisateur non trouvé"
      );
    }

    const userData = userDoc.data();
    console.log("Données utilisateur:", JSON.stringify(userData));

    if (!userData || !userData.stripeAccountId) {
      console.log("Erreur: Pas de Stripe Account ID trouvé");
      throw new functions.https.HttpsError(
        "failed-precondition",
        "L'utilisateur n'a pas de compte Stripe associé"
      );
    }

    const stripeAccountId = userData.stripeAccountId;

    // Création du produit dans Stripe
    console.log("Création du produit Stripe");
    const stripeProduct = await stripe.products.create(
      {
        name: data.name,
        description: data.description || "",
        metadata: {
          type: "service",
          duration: data.duration.toString(),
        },
      },
      {
        stripeAccount: stripeAccountId,
      }
    );
    console.log("Produit Stripe créé:", stripeProduct.id);

    // Création du prix dans Stripe
    console.log("Création du prix Stripe");
    const stripePrice = await stripe.prices.create(
      {
        product: stripeProduct.id,
        unit_amount: Math.round(data.price * 100),
        currency: "eur",
      },
      {
        stripeAccount: stripeAccountId,
      }
    );
    console.log("Prix Stripe créé:", stripePrice.id);

    // Création du service dans Firestore
    console.log("Ajout du service à Firestore");
    const serviceRef = admin.firestore().collection("services").doc();
    const serviceId = serviceRef.id;

    await serviceRef.set({
      id: serviceId,
      name: data.name,
      description: data.description || "",
      price: data.price,
      duration: data.duration,
      images: data.images || [],
      isActive: true,
      professionalId: context.auth.uid,
      stripeProductId: stripeProduct.id,
      stripePriceId: stripePrice.id,
      stripeAccountId: stripeAccountId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      serviceId: serviceId,
      stripeProductId: stripeProduct.id,
      stripePriceId: stripePrice.id,
    };
  } catch (error) {
    console.error("Erreur détaillée:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Impossible de créer le service: ${error.message}`
    );
  }
});

// Mise à jour d'un service
exports.updateService = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  const { serviceId, name, description, price, images, isActive } = data;

  try {
    // Récupérer le service existant
    const serviceDoc = await admin
      .firestore()
      .collection("services")
      .doc(serviceId)
      .get();
    if (!serviceDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Service non trouvé");
    }

    const serviceData = serviceDoc.data();
    const stripeAccountId = serviceData.stripeAccountId;

    // Mettre à jour le produit dans Stripe
    await stripe.products.update(
      serviceData.stripeProductId,
      {
        name,
        description,
        active: isActive,
      },
      {
        stripeAccount: stripeAccountId,
      }
    );

    // Si le prix a changé, créer un nouveau prix dans Stripe
    let newStripePriceId = serviceData.stripePriceId;
    if (price !== serviceData.price) {
      // Désactiver l'ancien prix
      await stripe.prices.update(
        serviceData.stripePriceId,
        { active: false },
        { stripeAccount: stripeAccountId }
      );

      // Créer un nouveau prix
      const newPrice = await stripe.prices.create(
        {
          product: serviceData.stripeProductId,
          unit_amount: Math.round(price * 100),
          currency: "eur",
        },
        {
          stripeAccount: stripeAccountId,
        }
      );
      newStripePriceId = newPrice.id;
    }

    // Mettre à jour dans Firestore
    await admin.firestore().collection("services").doc(serviceId).update({
      name,
      description,
      price,
      images,
      isActive,
      stripePriceId: newStripePriceId,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      stripePriceId: newStripePriceId,
    };
  } catch (error) {
    console.error("Erreur lors de la mise à jour du service:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

exports.getStripeInvoices = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié"
    );
  }

  try {
    // Récupérer le customer ID Stripe de l'utilisateur
    const customer = await stripe.customers.search({
      query: `metadata['firebaseUID']:'${context.auth.uid}'`,
    });

    if (!customer.data.length) {
      return { invoices: [] };
    }

    // Récupérer toutes les factures du client
    const invoices = await stripe.invoices.list({
      customer: customer.data[0].id,
      limit: 100,
    });

    // Formater les factures pour le client
    const formattedInvoices = invoices.data.map((invoice) => ({
      id: invoice.id,
      number: invoice.number,
      amount_paid: invoice.amount_paid,
      status: invoice.status,
      created: invoice.created,
      invoice_pdf: invoice.invoice_pdf,
      period_start: invoice.period_start,
      period_end: invoice.period_end,
    }));

    return { invoices: formattedInvoices };
  } catch (error) {
    console.error("Erreur lors de la récupération des factures:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Erreur lors de la récupération des factures"
    );
  }
});

// Suppression d'un service
exports.deleteService = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  const { serviceId } = data;

  try {
    // Récupérer le service
    const serviceDoc = await admin
      .firestore()
      .collection("services")
      .doc(serviceId)
      .get();
    if (!serviceDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Service non trouvé");
    }

    const serviceData = serviceDoc.data();
    const stripeAccountId = serviceData.stripeAccountId;

    // Désactiver le produit dans Stripe
    await stripe.products.update(
      serviceData.stripeProductId,
      { active: false },
      { stripeAccount: stripeAccountId }
    );

    // Désactiver le prix dans Stripe
    await stripe.prices.update(
      serviceData.stripePriceId,
      { active: false },
      { stripeAccount: stripeAccountId }
    );

    // Supprimer de Firestore
    await admin.firestore().collection("services").doc(serviceId).delete();

    return { success: true };
  } catch (error) {
    console.error("Erreur lors de la suppression du service:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Activer/désactiver un service
exports.toggleServiceStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  const { serviceId, isActive } = data;

  try {
    const serviceDoc = await admin
      .firestore()
      .collection("services")
      .doc(serviceId)
      .get();
    if (!serviceDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Service non trouvé");
    }

    const serviceData = serviceDoc.data();
    const stripeAccountId = serviceData.stripeAccountId;

    // Mettre à jour le statut dans Stripe
    await stripe.products.update(
      serviceData.stripeProductId,
      { active: isActive },
      { stripeAccount: stripeAccountId }
    );

    await stripe.prices.update(
      serviceData.stripePriceId,
      { active: isActive },
      { stripeAccount: stripeAccountId }
    );

    // Mettre à jour dans Firestore
    await admin.firestore().collection("services").doc(serviceId).update({
      isActive,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true };
  } catch (error) {
    console.error("Erreur lors de la mise à jour du statut du service:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Création d'une règle de disponibilité
exports.createAvailabilityRule = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "L'utilisateur doit être authentifié."
      );
    }

    try {
      const ruleRef = admin.firestore().collection("availabilityRules").doc();
      const ruleId = ruleRef.id;

      await ruleRef.set({
        id: ruleId,
        professionalId: data.professionalId,
        serviceId: data.serviceId,
        workDays: data.workDays,
        startTime: data.startTime,
        endTime: data.endTime,
        breakTimes: data.breakTimes || [],
        exceptionalClosedDates: data.exceptionalClosedDates || [],
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { ruleId };
    } catch (error) {
      console.error("Erreur lors de la création de la règle:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

// Mise à jour d'une règle
exports.updateAvailabilityRule = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "L'utilisateur doit être authentifié."
      );
    }

    try {
      const ruleRef = admin
        .firestore()
        .collection("availabilityRules")
        .doc(data.id);
      const ruleDoc = await ruleRef.get();

      if (!ruleDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Règle non trouvée");
      }

      await ruleRef.update({
        workDays: data.workDays,
        startTime: data.startTime,
        endTime: data.endTime,
        breakTimes: data.breakTimes || [],
        exceptionalClosedDates: data.exceptionalClosedDates || [],
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true };
    } catch (error) {
      console.error("Erreur lors de la mise à jour de la règle:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

// Génération des créneaux à partir des règles
exports.generateTimeSlots = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  const { serviceId, startDate, endDate } = data;

  try {
    // Récupérer les règles de disponibilité pour ce service
    const rulesSnapshot = await admin
      .firestore()
      .collection("availabilityRules")
      .where("serviceId", "==", serviceId)
      .where("isActive", "==", true)
      .get();

    if (rulesSnapshot.empty) {
      throw new functions.https.HttpsError(
        "not-found",
        "Aucune règle de disponibilité trouvée"
      );
    }

    const rule = rulesSnapshot.docs[0].data();
    const slots = [];

    // Générer les créneaux pour chaque jour dans la période
    for (
      let date = new Date(startDate);
      date <= new Date(endDate);
      date.setDate(date.getDate() + 1)
    ) {
      const dayOfWeek = date.getDay() || 7; // Convertir 0 (dimanche) en 7

      if (
        rule.workDays.includes(dayOfWeek) &&
        !rule.exceptionalClosedDates.some(
          (closedDate) =>
            closedDate.toDate().toDateString() === date.toDateString()
        )
      ) {
        const daySlots = generateDaySlots(date, rule);
        slots.push(...daySlots);
      }
    }

    // Sauvegarder les créneaux en batch
    const batch = admin.firestore().batch();
    slots.forEach((slot) => {
      const slotRef = admin.firestore().collection("generatedTimeSlots").doc();
      batch.set(slotRef, {
        ...slot,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();

    return { success: true, slotsCount: slots.length };
  } catch (error) {
    console.error("Erreur lors de la génération des créneaux:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Fonction utilitaire pour générer les créneaux d'une journée
async function generateDaySlots(date, rule) {
  const slots = [];
  const serviceDoc = await admin
    .firestore()
    .collection("services")
    .doc(rule.serviceId)
    .get();
  const serviceDuration = serviceDoc.data().duration;

  let currentTime = combineDateTime(date, rule.startTime);
  const endTime = combineDateTime(date, rule.endTime);

  while (currentTime < endTime) {
    // Vérifier si ce créneau n'est pas pendant une pause
    if (!isInBreakTime(currentTime, rule.breakTimes)) {
      slots.push({
        serviceId: rule.serviceId,
        professionalId: rule.professionalId,
        date: admin.firestore.Timestamp.fromDate(date),
        startTime: admin.firestore.Timestamp.fromDate(currentTime),
        endTime: admin.firestore.Timestamp.fromDate(
          new Date(currentTime.getTime() + serviceDuration * 60000)
        ),
        isAvailable: true,
      });
    }

    // Avancer au prochain créneau
    currentTime = new Date(currentTime.getTime() + serviceDuration * 60000);
  }

  return slots;
}

// Fonction utilitaire pour vérifier si un horaire est pendant une pause
function isInBreakTime(time, breakTimes) {
  return breakTimes.some((breakTime) => {
    const breakStart = combineDateTime(time, breakTime.start);
    const breakEnd = combineDateTime(time, breakTime.end);
    return time >= breakStart && time < breakEnd;
  });
}

// Fonction utilitaire pour combiner date et heure
function combineDateTime(date, time) {
  return new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate(),
    time.hours,
    time.minutes
  );
}

// Fonction permettant de créer un lien de paiement pour tous les types
exports.createUnifiedPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated."
    );
  }

  try {
    const { type, amount, metadata, successUrl, cancelUrl, isWeb } = data;

    // Récupérer les informations du client
    const customerSnapshot = await admin
      .firestore()
      .collection("users")
      .doc(context.auth.uid)
      .get();

    if (!customerSnapshot.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Utilisateur non trouvé."
      );
    }

    const customerData = customerSnapshot.data();

    // Récupérer ou créer le client Stripe
    let stripeCustomerId = customerData.stripeCustomerId;
    if (!stripeCustomerId) {
      // Créer un nouveau client Stripe
      const stripeCustomer = await stripe.customers.create({
        email: customerData.email,
        name: `${customerData.firstName} ${customerData.lastName}`,
        metadata: {
          firebaseUID: context.auth.uid,
        },
      });

      stripeCustomerId = stripeCustomer.id;

      // Mettre à jour l'utilisateur avec son ID Stripe
      await admin.firestore().collection("users").doc(context.auth.uid).update({
        stripeCustomerId: stripeCustomerId,
      });
    }

    // Préparer les metadata
    let processedMetadata = {
      customerEmail: customerData.email,
      customerName: `${customerData.firstName} ${customerData.lastName}`,
      ...metadata,
    };
    Object.keys(processedMetadata).forEach((key) => {
      processedMetadata[key] = String(processedMetadata[key] || "");
    });

    if (isWeb) {
      // Extraire l'ID existant de l'URL de succès
      const urlParams = new URL(successUrl).searchParams;
      let finalSuccessUrl = successUrl;

      // Ajouter le session_id à l'URL existante
      if (successUrl.includes("?")) {
        finalSuccessUrl = `${successUrl}&session_id={CHECKOUT_SESSION_ID}`;
      } else {
        finalSuccessUrl = `${successUrl}?session_id={CHECKOUT_SESSION_ID}`;
      }

      // Créer une session Checkout pour le web
      const session = await stripe.checkout.sessions.create({
        customer: stripeCustomerId,
        payment_method_types: ["card"],
        mode: "payment",
        success_url: finalSuccessUrl.replace("#/", ""),
        cancel_url: cancelUrl.replace("#/", ""),
        line_items: [
          {
            price_data: {
              currency: "eur",
              unit_amount: amount,
              product_data: {
                name:
                  type === "order"
                    ? "Commande Up !"
                    : type === "express_deal"
                    ? "Panier anti-gaspi"
                    : "Réservation de service",
              },
            },
            quantity: 1,
          },
        ],
        metadata: {
          type,
          userId: context.auth.uid,
          ...processedMetadata,
        },
      });

      // Stocker les informations de paiement en attente selon le type
      let collectionName;
      switch (type) {
        case "order":
          collectionName = "pending_orders";
          break;
        case "express_deal":
          collectionName = "pending_express_deal_payments";
          break;
        case "service":
          collectionName = "pending_service_payments";
          break;
        default:
          throw new Error("Type de paiement non supporté");
      }

      await admin.firestore().collection(collectionName).doc(session.id).set({
        userId: context.auth.uid,
        metadata: processedMetadata,
        status: "pending",
        type: type,
        amount: amount,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        url: session.url,
        sessionId: session.id,
      };
    } else {
      // Créer un Payment Intent pour mobile
      const paymentIntent = await stripe.paymentIntents.create({
        amount,
        currency: "eur",
        metadata: {
          type,
          userId: context.auth.uid,
          ...processedMetadata,
        },
      });

      return {
        clientSecret: paymentIntent.client_secret,
        sessionId: paymentIntent.id,
      };
    }
  } catch (error) {
    console.error("Payment creation error:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// Webhook handler (vérification du paiement et création de la commande selon le type)
exports.handleStripeWebhook = functions.https.onRequest(
  async (request, response) => {
    const sig = request.headers["stripe-signature"];
    const webhookSecret = stripeWebhooks.webhook2;
    let event;

    console.log("Webhook received");

    try {
      event = stripe.webhooks.constructEvent(
        request.rawBody,
        sig,
        webhookSecret
      );
      console.log("Event type:", event.type);

      if (
        event.type === "checkout.session.completed" ||
        event.type === "payment_intent.succeeded"
      ) {
        const paymentData = event.data.object;
        const metadata = paymentData.metadata || {};
        const type = metadata.type;

        console.log("Processing payment:", {
          type,
          paymentId: paymentData.id,
          metadata: metadata,
        });

        if (!type) {
          console.error("No payment type found in metadata");
          response.json({ received: true });
          return;
        }

        // Vérifier le statut du paiement
        if (
          paymentData.status !== "complete" &&
          paymentData.status !== "succeeded"
        ) {
          console.log(
            `Payment ${paymentData.id} not completed, status: ${paymentData.status}`
          );
          response.json({ received: true });
          return;
        }

        let result;
        try {
          switch (type) {
            case "order":
              result = await handleOrderPayment(paymentData);
              break;
            case "express_deal":
              result = await handleExpressDealPayment(paymentData);
              break;
            case "service":
              result = await handleServicePayment(paymentData);
              break;
            default:
              throw new Error(`Unknown payment type: ${type}`);
          }

          console.log(`Successfully processed ${type} payment:`, result);

          // Créer une notification
          if (type === "order") {
            await sendOrderNotifications(result.orderId, {
              ...pendingOrderData,
              userId: metadata.userId,
              amount: pendingOrderData.totalPrice * 100,
              userData: await admin
                .firestore()
                .collection("users")
                .doc(metadata.userId)
                .get()
                .then((doc) => doc.data()),
              companyData: await admin
                .firestore()
                .collection("companys")
                .doc(pendingOrderData.entrepriseId)
                .get()
                .then((doc) => doc.data()),
            });
          }
        } catch (error) {
          console.error(`Error processing ${type} payment:`, error);
          // On continue malgré l'erreur pour ne pas retraiter le webhook
        }
      }

      response.json({ received: true });
    } catch (error) {
      console.error("Webhook error:", error);
      response.status(400).send(`Webhook Error: ${error.message}`);
    }
  }
);

// Création commande classique
async function handleOrderPayment(paymentData) {
  const metadata = paymentData.metadata;
  const cartId = metadata.cartId;
  const orderId = metadata.orderId;
  const userId = metadata.userId;

  try {
    const pendingOrderDoc = await admin
      .firestore()
      .collection("pending_orders")
      .doc(orderId)
      .get();

    if (!pendingOrderDoc.exists) {
      console.error("Pending order not found for orderId:", orderId);
      throw new Error("Pending order not found");
    }

    const pendingOrderData = pendingOrderDoc.data();
    console.log("PendingOrderData:", pendingOrderData);

    // 1. Exécuter la transaction Firestore pour la gestion des stocks
    await admin.firestore().runTransaction(async (transaction) => {
      // LECTURES D'ABORD
      const productReads = await Promise.all(
        pendingOrderData.items.map(async (item) => {
          const productRef = admin
            .firestore()
            .collection("products")
            .doc(item.productId);
          return {
            ref: productRef,
            doc: await transaction.get(productRef),
            item: item,
          };
        })
      );

      const orderRef = admin.firestore().collection("orders").doc(orderId);

      // Créer la commande
      transaction.set(orderRef, {
        userId: userId,
        items: pendingOrderData.items,
        sellerId: pendingOrderData.sellerId,
        entrepriseId: pendingOrderData.entrepriseId,
        subtotal: pendingOrderData.subtotal,
        promoCode: pendingOrderData.promoCode,
        discountAmount: pendingOrderData.discountAmount,
        totalPrice: pendingOrderData.totalPrice,
        pickupAddress: pendingOrderData.pickupAddress,
        status: "paid",
        paymentId: paymentData.id, // Utiliser directement l'ID du payment intent
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt:
          pendingOrderData.createdAt ||
          admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Mise à jour des stocks
      for (const { ref, doc, item } of productReads) {
        if (!doc.exists) {
          console.error(`Product not found: ${item.productId}`);
          continue;
        }

        const productData = doc.data();
        const variant = productData.variants.find(
          (v) => v.id === item.variantId
        );

        if (!variant) {
          console.error(
            `Variant not found: ${item.variantId} for product ${item.productId}`
          );
          continue;
        }

        const updatedVariants = productData.variants.map((v) => {
          if (v.id === item.variantId) {
            return {
              ...v,
              stock: Math.max(0, v.stock - item.quantity),
            };
          }
          return v;
        });

        transaction.update(ref, { variants: updatedVariants });
      }

      // Supprimer le panier si nécessaire
      if (cartId) {
        const cartRef = admin.firestore().collection("carts").doc(cartId);
        transaction.delete(cartRef);
      }

      // Supprimer la commande en attente
      transaction.delete(pendingOrderDoc.ref);
    });

    // 2. Envoyer les notifications et emails
    await sendOrderNotifications(orderId, {
      ...pendingOrderData,
      userId,
      amount: pendingOrderData.totalPrice * 100, // Convertir en centimes pour la cohérence
      userData: await admin
        .firestore()
        .collection("users")
        .doc(userId)
        .get()
        .then((doc) => doc.data()),
      companyData: await admin
        .firestore()
        .collection("companys")
        .doc(pendingOrderData.entrepriseId)
        .get()
        .then((doc) => doc.data()),
    });

    console.log("Order successfully processed:", orderId);
    return { orderId };
  } catch (error) {
    console.error("Error processing order:", error);
    await admin.firestore().collection("payment_errors").add({
      orderId,
      error: error.message,
      paymentId: paymentData.id,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    throw error;
  }
}

// Fonction helper pour les notifications
async function sendOrderNotifications(orderId, orderData) {
  const batch = admin.firestore().batch();

  // Notification pour le professionnel
  const notificationProRef = admin
    .firestore()
    .collection("notifications_pro")
    .doc();
  batch.set(notificationProRef, {
    userId: orderData.sellerId,
    type: "order",
    title: "🛍️ Nouvelle commande reçue",
    message: `Un client vient de passer une commande d'un montant de ${(
      orderData.amount / 100
    ).toFixed(2)}€`,
    targetId: orderId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
  });

  // Notification pour le client
  const notificationClientRef = admin
    .firestore()
    .collection("notifications")
    .doc();
  batch.set(notificationClientRef, {
    userId: orderData.userId,
    type: "order",
    title: "🎉 Commande confirmée",
    message: `Votre commande d'un montant de ${(orderData.amount / 100).toFixed(
      2
    )}€ a été confirmée`,
    targetId: orderId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
  });

  await batch.commit();

  // Envoyer les emails
  try {
    await Promise.all([
      // Email au client
      transporter.sendMail({
        from: '"Up ! 🛍️" <happy.deals59@gmail.com>',
        to: orderData.userData.email,
        subject: "🎉 Votre commande est confirmée",
        html: generateOrderCustomerEmail(
          orderData,
          orderData.userData,
          orderId
        ),
      }),
      // Email au professionnel
      transporter.sendMail({
        from: '"Up ! 🛍️" <happy.deals59@gmail.com>',
        to: orderData.companyData.email,
        subject: "🛍️ Nouvelle commande reçue",
        html: generateOrderProfessionalEmail(
          orderData,
          orderData.userData,
          orderId
        ),
      }),
    ]);

    console.log("Emails envoyés avec succès");
  } catch (emailError) {
    console.error("Erreur lors de l'envoi des emails:", emailError);
  }

  // Envoyer une notification push au client si le token FCM existe
  if (orderData.userData.fcmToken) {
    const message = {
      notification: {
        title: "🎉 Commande confirmée",
        body: `Votre commande d'un montant de ${(
          orderData.amount / 100
        ).toFixed(2)}€ a été confirmée`,
      },
      data: {
        type: "order",
        targetId: orderId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      token: orderData.userData.fcmToken,
    };

    try {
      await admin.messaging().send(message);
      console.log("Notification push envoyée avec succès");
    } catch (error) {
      console.error("Erreur lors de l'envoi de la notification push:", error);
    }
  }
}

// Création commande deal express
async function handleExpressDealPayment(paymentData) {
  const metadata = paymentData.metadata;
  const dealId = metadata.postId;
  const reservationId = metadata.reservationId;

  if (!dealId) {
    throw new Error("No dealId found in metadata");
  }

  try {
    const batch = admin.firestore().batch();

    // Générer un code de validation de 6 caractères (lettres et chiffres)
    const generateValidationCode = () => {
      const characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
      let code = "";
      for (let i = 0; i < 6; i++) {
        code += characters.charAt(
          Math.floor(Math.random() * characters.length)
        );
      }
      return code;
    };

    const validationCode = generateValidationCode();

    // Créer la réservation
    const reservationRef = admin
      .firestore()
      .collection("reservations")
      .doc(reservationId);
    const reservationData = {
      postId: dealId,
      status: "confirmed",
      paymentId: paymentData.id,
      buyerId: metadata.userId,
      quantity: 1,
      pickupDate: admin.firestore.Timestamp.fromDate(
        new Date(metadata.pickupDate)
      ),
      price: parseFloat(metadata.price || "0"),
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      companyId: metadata.companyId,
      tva: parseFloat(metadata.tva || "0"),
      isValidated: false,
      basketType: metadata.basketType,
      companyName: metadata.companyName,
      pickupAddress: metadata.pickupAddress,
      validationCode: validationCode,
    };

    batch.set(reservationRef, reservationData);

    // Mettre à jour le compteur de paniers
    const dealRef = admin.firestore().collection("posts").doc(dealId);
    batch.update(dealRef, {
      basketCount: admin.firestore.FieldValue.increment(-1),
    });

    // Créer une notification pour le vendeur
    const notificationProRef = admin
      .firestore()
      .collection("notifications_pro")
      .doc();
    batch.set(notificationProRef, {
      userId: metadata.companyId,
      type: "deal_express",
      title: `🌱 Nouveau ${metadata.basketType} réservé`,
      message: `Un client vient de réserver un ${metadata.basketType}`,
      targetId: reservationId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });

    // Créer une notification pour le client
    const notificationClientRef = admin
      .firestore()
      .collection("notifications")
      .doc();
    batch.set(notificationClientRef, {
      userId: metadata.userId,
      type: "deal_express",
      title: "🎉 Réservation confirmée",
      message: `Votre réservation pour un ${metadata.basketType} a été confirmée`,
      targetId: reservationId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });

    await batch.commit();

    // Récupérer les informations de l'utilisateur et de l'entreprise
    const [userDoc, companyDoc] = await Promise.all([
      admin.firestore().collection("users").doc(metadata.userId).get(),
      admin.firestore().collection("companys").doc(metadata.companyId).get(),
    ]);

    if (!userDoc.exists || !companyDoc.exists) {
      throw new Error("User or company not found");
    }

    const userData = userDoc.data();
    const companyData = companyDoc.data();

    // Envoyer les emails
    try {
      await Promise.all([
        // Email au client
        transporter.sendMail({
          from: '"Up ! 🌱" <happy.deals59@gmail.com>',
          to: userData.email,
          subject: `🎉 Votre ${metadata.basketType}  est réservé !`,
          html: generateDealCustomerEmail(
            reservationData,
            userData,
            reservationId
          ),
        }),
        // Email au professionnel
        transporter.sendMail({
          from: '"Up ! 🌱" <happy.deals59@gmail.com>',
          to: companyData.email,
          subject: `🌟 Nouveau ${metadata.basketType} réservé`,
          html: generateDealProfessionalEmail(reservationData, userData),
        }),
      ]);

      console.log("Emails envoyés avec succès");
    } catch (emailError) {
      console.error("Erreur lors de l'envoi des emails:", emailError);
    }

    // Envoyer une notification push au client si le token FCM existe
    if (userData.fcmToken) {
      const message = {
        notification: {
          title: "🎉 Réservation confirmée",
          body: `Votre réservation pour un ${metadata.basketType} a été confirmée`,
        },
        data: {
          type: "deal_express",
          targetId: reservationId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        token: userData.fcmToken,
      };

      try {
        await admin.messaging().send(message);
        console.log("Notification push envoyée avec succès");
      } catch (error) {
        console.error("Erreur lors de l'envoi de la notification push:", error);
      }
    }

    // Programmer la suppression pour plus tard
    setTimeout(async () => {
      try {
        await admin
          .firestore()
          .collection("pending_express_deal_payments")
          .doc(paymentData.id)
          .delete();
      } catch (error) {
        console.error("Error deleting pending payment:", error);
      }
    }, 5 * 60 * 1000); // Supprime après 5 minutes

    return { reservationId: reservationRef.id };
  } catch (error) {
    console.error("Erreur lors du traitement du deal express:", error);
    throw error;
  }
}

// Création commande réservations
async function handleServicePayment(paymentData) {
  const metadata = paymentData.metadata;
  const serviceId = metadata.serviceId;
  const bookingId = metadata.bookingId;
  const bookingDateTime = new Date(metadata.bookingDateTime);
  const timestamp = admin.firestore.Timestamp.fromDate(bookingDateTime);

  if (!serviceId) {
    throw new Error("No serviceId found in metadata");
  }

  // Préparer les données de base de la réservation
  const bookingData = {
    serviceId: serviceId,
    status: "confirmed",
    paymentId: paymentData.id,
    userId: metadata.userId,
    professionalId: metadata.professionalId,
    bookingDateTime: timestamp,
    amount: parseFloat(metadata.amount || "0"),
    serviceName: metadata.serviceName,
    tva: parseFloat(metadata.tva || "0"),
    priceTTC: parseFloat(metadata.priceTTC || "0"),
    priceHT: parseFloat(metadata.priceHT || "0"),
    duration: metadata.duration,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    adresse: metadata.adresse,
  };

  // Ajouter les informations du code promo si présent
  if (metadata.promoApplied) {
    bookingData.promoCode = metadata.promoCode;
    bookingData.originalPrice = parseFloat(metadata.originalPrice);
    bookingData.discountAmount = parseFloat(metadata.discountAmount);
    bookingData.finalPrice = parseFloat(metadata.finalPrice);

    // Mettre à jour les statistiques du code promo
    try {
      const promoRef = admin
        .firestore()
        .collection("promo_codes")
        .where("code", "==", metadata.promoCode)
        .where("companyId", "==", metadata.professionalId)
        .limit(1);

      const promoSnapshot = await promoRef.get();
      if (!promoSnapshot.empty) {
        const promoDoc = promoSnapshot.docs[0];
        await promoDoc.ref.update({
          currentUses: admin.firestore.FieldValue.increment(1),
          usageHistory: admin.firestore.FieldValue.arrayUnion([
            metadata.userId,
          ]),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      console.error("Error updating promo code:", error);
      // Continue même si la mise à jour du code promo échoue
    }
  }

  try {
    // Créer la réservation
    const bookingRef = admin.firestore().collection("bookings").doc(bookingId);
    await bookingRef.set(bookingData);

    // Créer une notification pour le professionnel
    const notificationProRef = admin
      .firestore()
      .collection("notifications_pro")
      .doc();
    await notificationProRef.set({
      userId: metadata.professionalId,
      type: "booking",
      title: "✨ Nouvelle réservation",
      message: `Un client vient de réserver le service "${metadata.serviceName}"`,
      targetId: bookingId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });

    // Créer une notification pour le client
    const notificationClientRef = admin
      .firestore()
      .collection("notifications")
      .doc();
    await notificationClientRef.set({
      userId: metadata.userId,
      type: "booking",
      title: "🎉 Réservation confirmée",
      message: `Votre réservation pour "${metadata.serviceName}" a été confirmée`,
      targetId: bookingId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });

    // Récupérer les informations du client et du professionnel
    const [userDoc, companyDoc] = await Promise.all([
      admin.firestore().collection("users").doc(metadata.userId).get(),
      admin
        .firestore()
        .collection("companys")
        .doc(metadata.professionalId)
        .get(),
    ]);

    if (!userDoc.exists || !companyDoc.exists) {
      throw new Error("User or company not found");
    }

    const userData = userDoc.data();
    const companyData = companyDoc.data();

    // Envoyer les emails
    try {
      await Promise.all([
        // Email au client
        transporter.sendMail({
          from: '"Up ✨" <happy.deals59@gmail.com>',
          to: userData.email,
          subject: `✨ Votre réservation pour "${metadata.serviceName}" est confirmée`,
          html: generateServiceBookingCustomerEmail(
            bookingData,
            userData,
            companyData
          ),
        }),
        // Email au professionnel
        transporter.sendMail({
          from: '"Up ! ✨" <happy.deals59@gmail.com>',
          to: companyData.email,
          subject: `🎯 Nouvelle réservation pour "${metadata.serviceName}"`,
          html: generateServiceBookingProfessionalEmail(
            bookingData,
            userData,
            companyData
          ),
        }),
      ]);

      console.log("Emails envoyés avec succès");
    } catch (emailError) {
      console.error("Erreur lors de l'envoi des emails:", emailError);
    }

    // Envoyer une notification push au client si le token FCM existe
    if (userData.fcmToken) {
      const message = {
        notification: {
          title: "✨ Réservation confirmée",
          body: `Votre réservation pour "${metadata.serviceName}" a été confirmée`,
        },
        data: {
          type: "booking",
          targetId: bookingId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        token: userData.fcmToken,
      };

      try {
        await admin.messaging().send(message);
        console.log("Notification push envoyée avec succès");
      } catch (error) {
        console.error("Erreur lors de l'envoi de la notification push:", error);
      }
    }

    // Programmer la suppression du paiement en attente
    setTimeout(async () => {
      try {
        await admin
          .firestore()
          .collection("pending_service_payments")
          .doc(paymentData.id)
          .delete();
      } catch (error) {
        console.error("Error deleting pending payment:", error);
      }
    }, 5 * 60 * 1000);

    return { bookingId: bookingRef.id };
  } catch (error) {
    console.error("Error processing service booking:", error);
    throw error;
  }
}

// Fonction pour E-mails :

const EMAIL_LOGO_URL =
  "https://image.noelshack.com/fichiers/2024/50/2/1733820474-up-bleu.png";

// Fonction de base pour le template HTML
function getBaseEmailTemplate(content) {
  return `
    <!DOCTYPE html>
    <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            font-family: 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
          }
          .container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            overflow: hidden;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
          }
          .header {
            background-color: white;
            padding: 20px;
            text-align: center;
            border-bottom: 1px solid #eee;
          }
          .logo {
            width: 150px;
            height: auto;
          }
          .content {
            padding: 30px;
            background: white;
          }
          .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            font-size: 12px;
            color: #666;
          }
          .button {
            display: inline-block;
            padding: 12px 24px;
            background-color: #007bff;
            color: white !important; /* Force la couleur en blanc */
            text-decoration: none;
            border-radius: 6px;
            font-weight: 600;
            margin: 20px 0;
          }
          
          .button:hover,
          .button:visited,
          .button:active,
          .button:link {
            color: white !important;
            text-decoration: none;
          }
          .details-card {
            background: #f8f9fa;
            border-radius: 6px;
            padding: 20px;
            margin: 20px 0;
          }
          .price {
            font-size: 24px;
            color: #007bff;
            font-weight: bold;
          }
          h1 {
            color: #2c3e50;
            font-size: 24px;
            margin-bottom: 20px;
          }
          ul {
            list-style: none;
            padding: 0;
          }
          li {
            padding: 8px 0;
            border-bottom: 1px solid #eee;
          }
          .highlight {
            background-color: #e8f4ff;
            padding: 15px;
            border-radius: 6px;
            margin: 15px 0;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <img src="${EMAIL_LOGO_URL}" alt="Logo" class="logo">
          </div>
          <div class="content">
            ${content}
          </div>
          <div class="footer">
            <p>© ${new Date().getFullYear()} Up !. Tous droits réservés.</p>
            <p>
              <a href="https://votre-site.com/contact">Contact</a> |
              <a href="https://votre-site.com/conditions">Conditions</a> |
              <a href="https://votre-site.com/confidentialite">Confidentialité</a>
            </p>
          </div>
        </div>
      </body>
    </html>
  `;
}

// Template pour la commande classique (client)
function generateOrderCustomerEmail(orderData, customer, orderId) {
  const itemsList = orderData.items
    .map(
      (item) => `
      <li style="display: flex; justify-content: space-between; padding: 10px 0;">
        <span>${item.name} x ${item.quantity}</span>
        <span>${item.appliedPrice.toFixed(2)}€</span>
      </li>
    `
    )
    .join("");

  const content = `
    <h1>🎉 Votre commande est confirmée !</h1>
    <p>Bonjour ${customer.firstName},</p>
    <p>Votre commande a été confirmée avec succès. Merci de votre confiance !</p>
    
    <div class="details-card">
      <h2>🛍️ Détails de votre commande</h2>
      <ul>
        ${itemsList}
      </ul>
      <div class="highlight">
        <p>📍 Adresse de retrait :</p>
        <p>${orderData.pickupAddress}</p>
      </div>
      <div class="price">
        Total : ${orderData.totalPrice.toFixed(2)}€
      </div>
    </div>

    <div class="highlight">
      <p>⏰ N'oubliez pas : Vous pouvez retirer votre commande aux horaires d'ouverture du commerce.</p>
    </div>

    <a href="https://up-anti-gaspi.web.app/orders/${orderId}" class="button">
      Voir ma commande
    </a>
  `;

  return getBaseEmailTemplate(content);
}

// Template pour la commande classique (professionnel)
function generateOrderProfessionalEmail(orderData, customer, orderId) {
  const itemsList = orderData.items
    .map(
      (item) => `
      <li style="display: flex; justify-content: space-between; padding: 10px 0;">
        <span>${item.name} x ${item.quantity}</span>
        <span>${item.appliedPrice.toFixed(2)}€</span>
      </li>
    `
    )
    .join("");

  const content = `
    <h1>🛍️ Nouvelle commande reçue !</h1>
    <p>Une nouvelle commande vient d'être passée sur votre boutique.</p>
    
    <div class="details-card">
      <h2>👤 Informations client</h2>
      <ul>
        <li><strong>Nom :</strong> ${customer.firstName} ${
    customer.lastName
  }</li>
        <li><strong>Email :</strong> ${customer.email}</li>
      </ul>
    </div>

    <div class="details-card">
      <h2>📝 Détails de la commande</h2>
      <ul>
        ${itemsList}
      </ul>
      <div class="price">
        Total : ${orderData.totalPrice.toFixed(2)}€
      </div>
    </div>

    <a href="https://up-pro.vercel.app/dashboard/orders/${orderId}" class="button">
      Gérer la commande
    </a>
  `;

  return getBaseEmailTemplate(content);
}

// Template pour le deal express (client)
function generateDealCustomerEmail(orderData, customer, id) {
  // Convertir le timestamp Firestore en Date
  const pickupDate =
    orderData.pickupDate instanceof Date
      ? orderData.pickupDate
      : orderData.pickupDate.toDate();

  const content = `
    <h1>🌱 Votre ${orderData.basketType} réservé !</h1>
    <p>Bonjour ${customer.firstName},</p>
    <p>Votre ${
      orderData.basketType
    } a été réservé avec succès. <br>Merci de contribuer à la lutte contre le gaspillage alimentaire !</p>
    
    <div class="details-card">
      <h2>🛒 Détails de votre panier</h2>
      <ul>
        <li><strong>Type de panier :</strong> ${orderData.basketType}</li>
        <li><strong>À récupérer le :</strong> ${pickupDate.toLocaleString(
          "fr-FR",
          {
            weekday: "long",
            year: "numeric",
            month: "long",
            day: "numeric",
            hour: "2-digit",
            minute: "2-digit",
          }
        )}</li>
        <li><strong>Adresse :</strong> ${orderData.pickupAddress}</li>
      </ul>
      <div class="highlight">
        <p>🔑 Votre code de retrait :</p>
        <h2 style="text-align: center; letter-spacing: 5px; font-size: 32px; margin: 10px 0;">
          ${orderData.validationCode}
        </h2>
        <p style="font-size: 12px; text-align: center;">À présenter lors du retrait de votre panier</p>
      </div>
      <div class="price">
        ${orderData.price.toFixed(2)}€
      </div>
    </div>

    <div class="highlight">
      <p>⏰ N'oubliez pas : Récupérez votre panier à l'heure indiquée.</p>
    </div>

    <a href="https://up-anti-gaspi.web.app/reservations/${
      orderData.id
    }" class="button">
      Voir ma réservation
    </a>
  `;

  return getBaseEmailTemplate(content);
}

// Template pour le deal express (professionnel)
function generateDealProfessionalEmail(orderData, customer) {
  const content = `
    <h1>🌟 Nouveau ${orderData.basketType} réservé !</h1>
    <p>Un client vient de réserver un ${orderData.basketType}.</p>
    
    <div class="details-card">
      <h2>👤 Informations client</h2>
      <ul>
        <li><strong>Nom :</strong> ${customer.firstName} ${
    customer.lastName
  }</li>
        <li><strong>Email :</strong> ${customer.email}</li>
      </ul>
    </div>

    <div class="details-card">
      <h2>📝 Détails de la réservation</h2>
      <ul>
        <li><strong>Type de panier :</strong> ${orderData.basketType}</li>
        <li><strong>Date de retrait :</strong> ${new Date(
          orderData.pickupDate
        ).toLocaleString("fr-FR", {
          weekday: "long",
          year: "numeric",
          month: "long",
          day: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        })}</li>
      </ul>
      <div class="highlight">
        <p>Code de validation :</p>
        <h2 style="text-align: center; letter-spacing: 5px; font-size: 32px; margin: 10px 0;">
          ${orderData.validationCode}
        </h2>
      </div>
      <div class="price">
        ${orderData.price.toFixed(2)}€
      </div>
    </div>

    <a href="https://votre-site.com/pro/reservations/${
      orderData.id
    }" class="button">
      Gérer la réservation
    </a>
  `;

  return getBaseEmailTemplate(content);
}

// Fonction helper pour générer un code promo unique
async function generateUniquePromoCode() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let isUnique = false;
  let code = "";

  while (!isUnique) {
    // Générer un nouveau code
    code = "FID";
    for (let i = 0; i < 5; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }

    // Vérifier si le code existe déjà
    const existingCodes = await admin
      .firestore()
      .collection("promo_codes")
      .where("code", "==", code)
      .get();

    if (existingCodes.empty) {
      isUnique = true;
    }
  }

  return code;
}

// Templates d'emails
function generateServiceBookingCustomerEmail(bookingData, customer, bookingId) {
  // Convertir le timestamp Firestore en Date
  const bookingDate =
    bookingData.bookingDateTime instanceof Date
      ? bookingData.bookingDateTime
      : bookingData.bookingDateTime.toDate();

  const content = `
    <h1>✨ Votre réservation est confirmée !</h1>
    <p>Bonjour ${customer.firstName},</p>
    <p>Votre réservation a été confirmée avec succès. Nous avons hâte de vous accueillir !</p>
    
    <div class="details-card">
      <h2>📅 Détails de votre réservation</h2>
      <ul>
        <li><strong>Service :</strong> ${bookingData.serviceName}</li>
        <li><strong>Date :</strong> ${bookingDate.toLocaleString("fr-FR", {
          weekday: "long",
          year: "numeric",
          month: "long",
          day: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        })}</li>
        <li><strong>Durée :</strong> ${bookingData.duration} minutes</li>
        <li><strong>Adresse :</strong> ${bookingData.adresse}</li>
      </ul>
      <div class="price">
        ${bookingData.price.toFixed(2)}€
      </div>
    </div>

    <div class="highlight">
      <p>⏰ N'oubliez pas : Merci d'arriver quelques minutes avant votre rendez-vous.</p>
    </div>

    <a href="https://up-anti-gaspi.web.app/bookings/${bookingId}" class="button">
      Voir ma réservation
    </a>
  `;

  return getBaseEmailTemplate(content);
}

function generateServiceBookingProfessionalEmail(
  bookingData,
  customer,
  bookingId
) {
  // Convertir le timestamp Firestore en Date
  const bookingDate =
    bookingData.bookingDateTime instanceof Date
      ? bookingData.bookingDateTime
      : bookingData.bookingDateTime.toDate();

  const content = `
    <h1>✨ Nouvelle réservation reçue !</h1>
    <p>Un client vient de réserver un service.</p>
    
    <div class="details-card">
      <h2>👤 Informations client</h2>
      <ul>
        <li><strong>Nom :</strong> ${customer.firstName} ${
    customer.lastName
  }</li>
        <li><strong>Email :</strong> ${customer.email}</li>
      </ul>
    </div>

    <div class="details-card">
      <h2>📝 Détails de la réservation</h2>
      <ul>
        <li><strong>Service :</strong> ${bookingData.serviceName}</li>
        <li><strong>Date :</strong> ${bookingDate.toLocaleString("fr-FR", {
          weekday: "long",
          year: "numeric",
          month: "long",
          day: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        })}</li>
        <li><strong>Durée :</strong> ${bookingData.duration} minutes</li>
      </ul>
      <div class="price">
        ${bookingData.price.toFixed(2)}€
      </div>
    </div>

    <a href="https://up-pro.vercel.app/dashboard/bookings/${bookingId}" class="button">
      Gérer la réservation
    </a>
  `;

  return getBaseEmailTemplate(content);
}

// Fonction utilitaire pour gérer les points de fidélité
async function handleLoyaltyPoints(batch, userId, amount, type, referenceId) {
  try {
    console.log(
      `Traitement des points de fidélité pour l'utilisateur ${userId}`
    );

    // Arrondir le montant à l'entier le plus proche pour les points
    const pointsToAdd = Math.round(amount);

    // Référence au document de l'utilisateur
    const userRef = admin.firestore().collection("users").doc(userId);

    // Mettre à jour les points de l'utilisateur
    batch.update(userRef, {
      loyaltyPoints: admin.firestore.FieldValue.increment(pointsToAdd),
    });

    // Créer l'entrée dans l'historique
    const historyRef = admin.firestore().collection("pointsHistory").doc();
    batch.set(historyRef, {
      userId: userId,
      points: pointsToAdd,
      amount: amount,
      type: type, // 'order', 'reservation', ou 'booking'
      referenceId: referenceId, // orderId, reservationId, ou bookingId
      date: admin.firestore.FieldValue.serverTimestamp(),
      status: "earned",
    });

    console.log(`${pointsToAdd} points ajoutés pour l'utilisateur ${userId}`);
  } catch (error) {
    console.error("Erreur lors du traitement des points de fidélité:", error);
    throw error;
  }
}

exports.onOrderStatusUpdate = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const newValue = change.after.data();
    const previousValue = change.before.data();

    if (
      newValue.status === "completed" &&
      previousValue.status !== "completed"
    ) {
      console.log("=== Début traitement commande completed ===");

      const sellerId = newValue.sellerId;
      const userId = newValue.userId;
      const totalAmount = parseFloat(newValue.totalPrice);

      if (isNaN(totalAmount) || totalAmount <= 0) {
        console.error(
          `Montant total invalide pour la commande ${context.params.orderId}: ${totalAmount}`
        );
        return null;
      }

      try {
        // Créer le batch au début
        const batch = admin.firestore().batch();

        // Calculs des frais
        const feePercentage = 7.5;
        const feeAmount = (totalAmount * feePercentage) / 100;
        const amountAfterFee = totalAmount - feeAmount;

        // Vérifier l'entreprise
        const companySnapshot = await admin
          .firestore()
          .collection("companys")
          .doc(sellerId)
          .get();

        if (!companySnapshot.exists) {
          console.error(
            `Aucune entreprise trouvée pour le sellerId: ${sellerId}`
          );
          return null;
        }

        // Mise à jour des soldes
        batch.update(admin.firestore().collection("companys").doc(sellerId), {
          totalGain: admin.firestore.FieldValue.increment(totalAmount),
          totalFees: admin.firestore.FieldValue.increment(feeAmount),
          availableBalance:
            admin.firestore.FieldValue.increment(amountAfterFee),
        });

        // Enregistrement de la transaction
        const transactionRef = admin
          .firestore()
          .collection("transactions")
          .doc();
        batch.set(transactionRef, {
          companyId: sellerId,
          orderId: context.params.orderId,
          totalAmount: totalAmount,
          feeAmount: feeAmount,
          amountAfterFee: amountAfterFee,
          type: "credit",
          status: "completed",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        //Traiter les points de fidélité Up
        await handleLoyaltyPoints(
          batch,
          userId,
          totalAmount,
          "order",
          context.params.orderId
        );

        // Traiter la carte de fidélité AVANT le commit
        console.log("Début traitement carte de fidélité");
        await handleLoyaltyCard(
          batch, // Passer le même batch
          userId,
          sellerId,
          totalAmount,
          context.params.orderId
        );
        console.log("Fin traitement carte de fidélité");

        // Commit du batch APRÈS handleLoyaltyCard
        console.log("Début commit batch");
        await batch.commit();
        console.log("Fin commit batch");

        console.log(
          `Solde mis à jour pour l'entreprise: ${sellerId}, Montant total: ${totalAmount}`
        );
      } catch (error) {
        console.error("Erreur lors du traitement:", error);
        console.error("Détails de l'erreur:", JSON.stringify(error));
        throw error; // Propager l'erreur pour que Firebase la log
      }
    }
    return null;
  });

exports.onReservationStatusUpdate = functions.firestore
  .document("reservations/{reservationId}")
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const previousData = change.before.data();
    const reservationId = context.params.reservationId;

    if (newData.status === previousData.status) {
      return null;
    }

    try {
      const batch = admin.firestore().batch();

      if (newData.status === "completed") {
        const companyRef = admin
          .firestore()
          .collection("companys")
          .doc(newData.companyId);
        const companyDoc = await companyRef.get();

        if (companyDoc.exists) {
          const totalAmount = newData.price * newData.quantity;
          const commission = totalAmount * 0.075;
          const montantNet = totalAmount - commission;

          batch.update(companyRef, {
            availableBalance: admin.firestore.FieldValue.increment(montantNet),
            totalEarnings: admin.firestore.FieldValue.increment(totalAmount),
            totalCommissions: admin.firestore.FieldValue.increment(commission),
          });

          const transactionRef = admin
            .firestore()
            .collection("transactions")
            .doc();
          batch.set(transactionRef, {
            companyId: newData.companyId,
            reservationId: reservationId,
            totalAmount: totalAmount,
            feeAmount: commission,
            amountAfterFee: montantNet,
            dealExpressId: newData.postId,
            type: "credit",
            status: "completed",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          //Traiter les points de fidélité Up
          await handleLoyaltyPoints(
            batch,
            newData.buyerId,
            totalAmount,
            "reservation",
            context.params.reservationId
          );
          // Gestion de la carte de fidélité
          await handleLoyaltyCard(
            batch,
            newData.buyerId,
            newData.companyId,
            totalAmount,
            null,
            reservationId
          );
        }
      }

      // Gestion des notifications
      let notificationData;
      if (["prête à être retirée", "completed"].includes(newData.status)) {
        const notificationRef = admin
          .firestore()
          .collection("notifications")
          .doc();
        notificationData = {
          userId: newData.buyerId,
          targetId: reservationId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          type: "deal_express",
        };

        if (newData.status === "prête à être retirée") {
          notificationData = {
            ...notificationData,
            title: "Panier prêt",
            message: `Votre ${newData.basketType} est prêt à être retiré. Code de retrait : ${newData.validationCode}`,
          };
        } else if (newData.status === "completed") {
          notificationData = {
            ...notificationData,
            title: "Commande terminée",
            message: `Votre ${newData.basketType} a bien été récupéré`,
          };
        }

        batch.set(notificationRef, notificationData);
      }

      // Commit du batch AVANT l'envoi de la notification push
      await batch.commit();

      // Envoi de la notification push APRÈS le commit du batch
      if (["prête à être retirée", "completed"].includes(newData.status)) {
        const userDoc = await admin
          .firestore()
          .collection("users")
          .doc(newData.buyerId)
          .get();

        const fcmToken = userDoc.data()?.fcmToken;

        if (fcmToken) {
          const message = {
            notification: {
              title: notificationData.title,
              body: notificationData.message,
            },
            data: {
              type: "reservation",
              targetId: reservationId,
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            token: fcmToken,
          };

          try {
            await admin.messaging().send(message);
            console.log("Notification push envoyée avec succès");
          } catch (error) {
            console.error(
              "Erreur lors de l'envoi de la notification push:",
              error
            );
          }
        }
      }

      return null;
    } catch (error) {
      console.error("Erreur lors du traitement de la réservation:", error);
      throw error; // Propager l'erreur pour que Firebase la log
    }
  });

exports.onBookingStatusUpdate = functions.firestore
  .document("bookings/{bookingId}")
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const previousData = change.before.data();
    const bookingId = context.params.bookingId;

    if (newData.status === previousData.status) {
      return null;
    }

    try {
      const batch = admin.firestore().batch();

      if (newData.status === "completed") {
        console.log("=== Début traitement booking completed ===");

        const companyRef = admin
          .firestore()
          .collection("companys")
          .doc(newData.professionalId);
        const companyDoc = await companyRef.get();

        if (companyDoc.exists) {
          const totalAmount = newData.amount / 100;
          const commission = totalAmount * 0.075;
          const montantNet = totalAmount - commission;

          batch.update(companyRef, {
            availableBalance: admin.firestore.FieldValue.increment(montantNet),
            totalEarnings: admin.firestore.FieldValue.increment(totalAmount),
            totalCommissions: admin.firestore.FieldValue.increment(commission),
          });

          const transactionRef = admin
            .firestore()
            .collection("transactions")
            .doc();
          batch.set(transactionRef, {
            companyId: newData.professionalId,
            bookingId: bookingId,
            totalAmount: totalAmount,
            feeAmount: commission,
            amountAfterFee: montantNet,
            type: "credit",
            status: "completed",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          //Traiter les points de fidélité Up
          await handleLoyaltyPoints(
            batch,
            newData.userId,
            totalAmount,
            "booking",
            context.params.bookingId
          );
          // Gestion de la carte de fidélité AVANT les notifications
          console.log("Début traitement carte de fidélité");
          await handleLoyaltyCard(
            batch,
            newData.userId,
            newData.professionalId,
            totalAmount,
            null,
            null,
            bookingId
          );
          console.log("Fin traitement carte de fidélité");
        }
      }

      // Gestion des notifications
      if (["completed", "cancelled"].includes(newData.status)) {
        const notificationRef = admin
          .firestore()
          .collection("notifications")
          .doc();
        let notificationData = {
          userId: newData.userId,
          targetId: bookingId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          isRead: false,
          type: "booking",
        };

        if (newData.status === "completed") {
          notificationData = {
            ...notificationData,
            title: "Service terminé",
            message: `Votre rendez-vous pour ${newData.serviceName} est terminé`,
          };
        } else if (newData.status === "cancelled") {
          notificationData = {
            ...notificationData,
            title: "Service annulé",
            message: `Votre rendez-vous pour ${newData.serviceName} a été annulé`,
          };
        }

        batch.set(notificationRef, notificationData);
      }

      // Commit du batch AVANT l'envoi de la notification push
      console.log("Début commit batch");
      await batch.commit();
      console.log("Fin commit batch");

      // Envoi de la notification push APRÈS le commit du batch
      if (["completed", "cancelled"].includes(newData.status)) {
        const userDoc = await admin
          .firestore()
          .collection("users")
          .doc(newData.userId)
          .get();

        const fcmToken = userDoc.data()?.fcmToken;

        if (fcmToken) {
          const message = {
            notification: {
              title: notificationData.title,
              body: notificationData.message,
            },
            data: {
              type: "booking",
              targetId: bookingId,
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            token: fcmToken,
          };

          try {
            await admin.messaging().send(message);
            console.log("Notification push envoyée avec succès");
          } catch (error) {
            console.error(
              "Erreur lors de l'envoi de la notification push:",
              error
            );
          }
        }
      }

      return null;
    } catch (error) {
      console.error("Erreur lors du traitement de la réservation:", error);
      throw error; // Propager l'erreur pour que Firebase la log
    }
  });

async function handleLoyaltyCard(
  batch,
  userId,
  companyId,
  amount,
  orderId = null,
  reservationId = null,
  bookingId = null
) {
  console.log("=== Début handleLoyaltyCard ===");
  console.log("Paramètres reçus:", {
    userId,
    companyId,
    amount,
    orderId,
    reservationId,
    bookingId,
  });

  try {
    // 1. Vérifier si le vendeur a un programme de fidélité actif
    const companyDoc = await admin
      .firestore()
      .collection("companys")
      .doc(companyId)
      .get();

    const loyaltyProgramId = companyDoc.data()?.loyaltyProgramId;

    if (!loyaltyProgramId) {
      console.log("Pas de programme de fidélité associé à l'entreprise");
      return;
    }

    const loyaltyProgramDoc = await admin
      .firestore()
      .collection("LoyaltyPrograms")
      .doc(loyaltyProgramId)
      .get();

    console.log("Programme de fidélité trouvé:", {
      exists: loyaltyProgramDoc.exists,
      status: loyaltyProgramDoc.exists ? loyaltyProgramDoc.data().status : null,
    });

    if (
      !loyaltyProgramDoc.exists ||
      loyaltyProgramDoc.data().status !== "active"
    ) {
      console.log("Programme de fidélité non actif, sortie de la fonction");
      return;
    }

    const loyaltyProgram = loyaltyProgramDoc.data();
    console.log("Type de programme:", loyaltyProgram.type);

    // 2. Calculer les points/visites à ajouter selon le type de programme
    let earnedValue = 0;
    switch (loyaltyProgram.type) {
      case "visits":
        earnedValue = 1;
        break;
      case "points":
        earnedValue = Math.floor(amount);
        break;
      case "amount":
        earnedValue = Math.round(amount); // Arrondir le montant
        break;
    }

    console.log("Valeur gagnée (arrondie):", earnedValue);

    let remainingValue = earnedValue;
    console.log("Valeur initiale à traiter:", remainingValue);
    let currentCardValue = 0;
    let currentCardRef = null;

    // Rechercher une carte active une seule fois avant la boucle
    const existingCardQuery = await admin
      .firestore()
      .collection("LoyaltyCards")
      .where("customerId", "==", userId)
      .where("companyId", "==", companyId)
      .where("status", "==", "active")
      .get();

    if (existingCardQuery.empty) {
      currentCardRef = admin.firestore().collection("LoyaltyCards").doc();
      batch.set(currentCardRef, {
        customerId: userId,
        companyId: companyId,
        loyaltyProgramId: loyaltyProgramId,
        currentValue: 0,
        totalEarned: 0,
        totalRedeemed: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "active",
        lastTransaction: {
          date: admin.firestore.FieldValue.serverTimestamp(),
          amount: 0,
          type: "create",
        },
      });
      console.log("Nouvelle carte créée:", currentCardRef.id);
    } else {
      currentCardRef = existingCardQuery.docs[0].ref;
      currentCardValue = existingCardQuery.docs[0].data().currentValue;
      console.log(
        "Carte existante trouvée:",
        currentCardRef.id,
        "avec valeur:",
        currentCardValue
      );
    }

    // Créer l'historique
    const historyRef = admin.firestore().collection("LoyaltyHistory").doc();
    const historyData = {
      customerId: userId,
      companyId: companyId,
      amount: earnedValue,
      type: "earn",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      details: [],
      // Ajouter la référence appropriée
      ...(orderId && { orderId }),
      ...(reservationId && { reservationId }),
      ...(bookingId && { bookingId }),
    };

    while (remainingValue > 0) {
      const targetValue =
        loyaltyProgram.type === "points"
          ? Math.min(...Object.keys(loyaltyProgram.tiers).map(Number))
          : loyaltyProgram.targetValue;

      const valueNeededForTarget = targetValue - currentCardValue;
      const valueToAdd = Math.min(remainingValue, valueNeededForTarget);
      const willReachTarget = valueToAdd >= valueNeededForTarget;

      if (willReachTarget) {
        // Compléter la carte
        console.log(`Complétion d'une carte avec ${valueNeededForTarget}`);

        batch.update(currentCardRef, {
          currentValue: targetValue,
          totalEarned:
            admin.firestore.FieldValue.increment(valueNeededForTarget),
          status: "completed",
          lastTransaction: {
            date: admin.firestore.FieldValue.serverTimestamp(),
            amount: valueNeededForTarget,
            type: "earn",
          },
        });

        // Ajouter à l'historique
        historyData.details.push({
          cardId: currentCardRef.id,
          amount: valueNeededForTarget,
          type: "complete_card",
          finalValue: targetValue,
        });

        // Créer le code promo
        const promoCode = await generateUniquePromoCode();
        const promoRef = admin.firestore().collection("promo_codes").doc();

        let rewardValue = 0;
        let isPercentage = false;

        if (loyaltyProgram.type === "points" && loyaltyProgram.tiers) {
          const reward = loyaltyProgram.tiers[targetValue];
          rewardValue = reward.reward;
          isPercentage = reward.isPercentage;
        } else {
          rewardValue = loyaltyProgram.rewardValue;
          isPercentage = loyaltyProgram.isPercentage;
        }

        batch.set(promoRef, {
          applicableTo: "all",
          code: promoCode,
          customerId: userId,
          companyId: companyId,
          discountValue: rewardValue,
          isPercentage: isPercentage,
          isActive: true,
          usageHistory: [],
          discountType: isPercentage ? "percentage" : "amount",
          status: "active",
          isPublic: false,
          currentUses: 0,
          maxUses: "1",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
          ),
          loyaltyCardId: currentCardRef.id,
        });
        // Mettre à jour la valeur restante
        remainingValue -= valueNeededForTarget;

        // Créer une nouvelle carte si nécessaire
        if (remainingValue > 0) {
          currentCardRef = admin.firestore().collection("LoyaltyCards").doc();
          currentCardValue = 0;
          batch.set(currentCardRef, {
            customerId: userId,
            companyId: companyId,
            loyaltyProgramId: loyaltyProgramId,
            currentValue: 0,
            totalEarned: 0,
            totalRedeemed: 0,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            status: "active",
            lastTransaction: {
              date: admin.firestore.FieldValue.serverTimestamp(),
              amount: 0,
              type: "create",
            },
          });
        }
      } else {
        // Ajouter le montant partiel
        console.log(`Ajout partiel de ${valueToAdd} à la carte`);

        const newValue = currentCardValue + valueToAdd;
        batch.update(currentCardRef, {
          currentValue: newValue,
          totalEarned: admin.firestore.FieldValue.increment(valueToAdd),
          lastTransaction: {
            date: admin.firestore.FieldValue.serverTimestamp(),
            amount: valueToAdd,
            type: "earn",
          },
        });

        // Ajouter à l'historique
        historyData.details.push({
          cardId: currentCardRef.id,
          amount: valueToAdd,
          type: "partial_card",
          finalValue: newValue,
        });

        remainingValue = 0;
      }
    }

    // Ajouter l'historique complet
    batch.set(historyRef, historyData);
  } catch (error) {
    console.error("Erreur lors du traitement de la carte de fidélité:", error);
    throw error;
  }
}

exports.sendTrainingRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Utilisateur non authentifié"
    );
  }

  const { firstName, lastName, companyName, phone, email, address, userId } =
    data;

  // Configuration de l'email
  const mailOptions = {
    from: '"Up ! 🛍️" <happy.deals59@gmail.com>',
    to: "happy.deals59@gmail.com", // Email où recevoir les demandes
    subject: "Nouvelle demande de formation Up!",
    html: `
          <h2>Nouvelle demande de formation</h2>
          <p><strong>Client :</strong> ${firstName} ${lastName}</p>
          <p><strong>Entreprise/Association :</strong> ${companyName}</p>
          <p><strong>Téléphone :</strong> ${phone}</p>
          <p><strong>Email :</strong> ${email}</p>
          <p><strong>Adresse :</strong> ${address}</p>
          <p><strong>ID Utilisateur :</strong> ${userId}</p>
      `,
  };

  try {
    await transporter.sendMail(mailOptions);
    return { success: true };
  } catch (error) {
    console.error("Erreur lors de l'envoi de l'email:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Erreur lors de l'envoi de l'email"
    );
  }
});
