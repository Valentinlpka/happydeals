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

    const account = await stripe.accounts.create({
      type: "express",
      country: "FR",
      email: userData.email,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
    });

    await admin.firestore().collection("users").doc(context.auth.uid).update({
      stripeAccountId: account.id,
    });

    const accountLink = await stripe.accountLinks.create({
      account: account.id,
      refresh_url: `https://yourapp.com/reauth`,
      return_url: `https://yourapp.com/return`,
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
    refresh_url: `https://yourapp.com/reauth`,
    return_url: `https://yourapp.com/return`,
    type: "account_onboarding",
  });

  return { url: accountLink.url };
});

// Mettre à jour le plafond du pro
exports.updateMerchantBalance = functions.firestore
  .document("orders/{orderId}")
  .onUpdate(async (change, context) => {
    const newValue = change.after.data();
    const previousValue = change.before.data();

    if (
      newValue.status === "completed" &&
      previousValue.status !== "completed"
    ) {
      const sellerId = newValue.sellerId;
      const totalAmount = parseFloat(newValue.totalPrice);

      if (isNaN(totalAmount) || totalAmount <= 0) {
        console.error(
          `Montant total invalide pour la commande ${context.params.orderId}: ${totalAmount}`
        );
        return null;
      }

      const feePercentage = 7.5;
      const feeAmount = (totalAmount * feePercentage) / 100;
      const amountAfterFee = totalAmount - feeAmount;

      console.log(`Traitement de la commande ${context.params.orderId}:`);
      console.log(`  Total: ${totalAmount}`);
      console.log(`  Frais: ${feeAmount}`);
      console.log(`  Montant après frais: ${amountAfterFee}`);

      try {
        // Recherche de l'entreprise correspondante dans la collection "companys"
        const companySnapshot = await admin
          .firestore()
          .collection("companys")
          .where("sellerId", "==", sellerId)
          .limit(1)
          .get();

        if (companySnapshot.empty) {
          console.error(
            `Aucune entreprise trouvée pour le sellerId: ${sellerId}`
          );
          return null;
        }

        const companyDoc = companySnapshot.docs[0];
        const companyId = companyDoc.id;

        // Mise à jour des soldes de l'entreprise
        await admin
          .firestore()
          .collection("companys")
          .doc(companyId)
          .update({
            totalGain: admin.firestore.FieldValue.increment(totalAmount),
            totalFees: admin.firestore.FieldValue.increment(feeAmount),
            availableBalance:
              admin.firestore.FieldValue.increment(amountAfterFee),
          });

        // Enregistrement de la transaction
        await admin.firestore().collection("transactions").add({
          companyId: companyId,
          orderId: context.params.orderId,
          totalAmount: totalAmount,
          feeAmount: feeAmount,
          amountAfterFee: amountAfterFee,
          type: "credit",
          status: "completed",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(
          `Solde mis à jour pour l'entreprise: ${companyId}, Montant total: ${totalAmount}, Montant après frais: ${amountAfterFee}`
        );
      } catch (error) {
        console.error("Erreur lors de la mise à jour du solde:", error);
        console.error("Détails de l'erreur:", JSON.stringify(error));
      }
    }
    return null;
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
      variants: variantsWithStripeData,
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

    // Création du lien de paiement pour le web
    const session = await stripe.checkout.sessions.create({
      mode: "payment",
      success_url: `${data.successUrl}?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: data.cancelUrl,
      payment_method_types: ["card"],
      line_items: [
        {
          price: price.id,
          quantity: 1,
        },
      ],
    });

    return {
      success: true,
      stripeProductId: product.id,
      stripePriceId: price.id,
      sessionUrl: session.url,
      sessionId: session.id,
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

// Fonction utilitaire pour vérifier la disponibilité
async function checkAvailability(serviceId, bookingDateTime) {
  try {
    const date = new Date(bookingDateTime);

    // Récupérer la règle de disponibilité
    const rulesSnapshot = await admin
      .firestore()
      .collection("availabilityRules")
      .where("serviceId", "==", serviceId)
      .where("isActive", "==", true)
      .get();

    if (rulesSnapshot.empty) {
      return false;
    }

    const rule = rulesSnapshot.docs[0].data();

    // Vérifier si c'est un jour travaillé
    if (!rule.workDays.includes(date.getDay() || 7)) {
      return false;
    }

    // Vérifier les dates exceptionnelles
    const isExceptionalDate = rule.exceptionalClosedDates.some(
      (closedDate) => closedDate.toDate().toDateString() === date.toDateString()
    );
    if (isExceptionalDate) {
      return false;
    }

    // Vérifier l'heure
    const hour = date.getHours();
    const minutes = date.getMinutes();

    if (
      hour < rule.startTime.hours ||
      (hour === rule.startTime.hours && minutes < rule.startTime.minutes) ||
      hour > rule.endTime.hours ||
      (hour === rule.endTime.hours && minutes > rule.endTime.minutes)
    ) {
      return false;
    }

    // Vérifier les pauses
    const isInBreak = rule.breakTimes.some((breakTime) => {
      const breakStart = breakTime.start;
      const breakEnd = breakTime.end;

      return (
        (hour > breakStart.hours ||
          (hour === breakStart.hours && minutes >= breakStart.minutes)) &&
        (hour < breakEnd.hours ||
          (hour === breakEnd.hours && minutes <= breakEnd.minutes))
      );
    });
    if (isInBreak) {
      return false;
    }

    // Vérifier s'il n'y a pas déjà une réservation
    const bookingsSnapshot = await admin
      .firestore()
      .collection("bookings")
      .where("serviceId", "==", serviceId)
      .where("bookingDateTime", "==", admin.firestore.Timestamp.fromDate(date))
      .where("status", "in", ["confirmed", "pending"])
      .get();

    return bookingsSnapshot.empty;
  } catch (error) {
    console.error("Error checking availability:", error);
    return false;
  }
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

    // Préparer les metadata proprement
    let processedMetadata = {};

    // Traiter chaque clé individuellement
    Object.keys(metadata).forEach((key) => {
      let value = metadata[key];

      // Traitement spécial pour les items
      if (key === "items" && Array.isArray(value)) {
        value = value.map((item) => ({
          productId: item.productId || "",
          name: item.name || "",
          quantity: String(item.quantity || 0),
          price: String(item.price || 0),
          appliedPrice: String(item.appliedPrice || 0),
          // autres champs nécessaires...
        }));
      }

      // Convertir en string de manière sûre
      processedMetadata[key] =
        typeof value === "object" ? JSON.stringify(value) : String(value || "");
    });

    // Log pour debug
    console.log("Processed metadata:", processedMetadata);

    const sessionData = {
      payment_method_types: ["card"],
      mode: "payment",
      success_url: `${successUrl}?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: cancelUrl,
      line_items: [
        {
          price_data: {
            currency: "eur",
            unit_amount: amount,
            product_data: {
              name: type === "order" ? "Commande Happy Deals" : "Paiement",
              description: processedMetadata.promoCode
                ? `Code promo appliqué: ${processedMetadata.promoCode}`
                : undefined,
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
    };

    // Log pour debug
    console.log("Session data:", sessionData);

    const session = await stripe.checkout.sessions.create(sessionData);

    // Stocker la transaction en attente
    await admin
      .firestore()
      .collection(`pending_${type}_payments`)
      .doc(session.id)
      .set({
        userId: context.auth.uid,
        amount,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        metadata: processedMetadata,
      });

    return {
      sessionId: session.id,
      url: session.url,
    };
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
          await createPaymentNotification({
            type,
            paymentId: paymentData.id,
            metadata: metadata,
            result: result,
          });
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
async function handleOrderPayment(session) {
  const metadata = session.metadata;
  const { orderId, cartId, userId } = metadata;

  try {
    const pendingOrderDoc = await admin
      .firestore()
      .collection("pending_orders")
      .doc(orderId)
      .get();

    if (!pendingOrderDoc.exists) {
      throw new Error("Pending order not found");
    }

    const pendingOrderData = pendingOrderDoc.data();
    console.log("PendingOrderData:", pendingOrderData);

    // 1. Exécuter la transaction Firestore
    await admin.firestore().runTransaction(async (transaction) => {
      // LECTURES D'ABORD
      // Lire tous les documents de produits nécessaires
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

      // PUIS LES ÉCRITURES
      const orderRef = admin.firestore().collection("orders").doc(orderId);

      // Mise à jour de la commande
      transaction.set(orderRef, {
        ...pendingOrderData,
        status: "paid",
        paymentId: session.payment_intent,
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
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

      // Suppression du panier
      if (cartId) {
        const cartRef = admin.firestore().collection("carts").doc(cartId);
        transaction.delete(cartRef);
      }

      // Suppression de la commande en attente
      transaction.delete(pendingOrderDoc.ref);

      // Notifications
      const notificationsRef = admin.firestore().collection("notifications");
      if (pendingOrderData.sellerId) {
        transaction.set(notificationsRef.doc(), {
          userId,
          type: "order_confirmed",
          title: "Commande confirmée",
          message: `Votre commande #${orderId} a été confirmée`,
          orderId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
        });

        transaction.set(notificationsRef.doc(), {
          userId: pendingOrderData.sellerId,
          type: "new_order",
          title: "Nouvelle commande",
          message: `Nouvelle commande #${orderId} reçue`,
          orderId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          read: false,
        });
      }
    });

    // 2. Après la transaction, gérer l'envoi des emails
    if (pendingOrderData.entrepriseId) {
      console.log("ProfessionalId found:", pendingOrderData.entrepriseId);

      // Vérifier que professionalId existe
      const [userDoc, companyDoc] = await Promise.all([
        admin.firestore().collection("users").doc(userId).get(),
        admin
          .firestore()
          .collection("companys")
          .doc(pendingOrderData.entrepriseId)
          .get(),
      ]);

      console.log("User exists:", userDoc.exists);
      console.log("Company exists:", companyDoc.exists);

      if (!userDoc.exists || !companyDoc.exists) {
        throw new Error("User or company not found");
      }

      const userData = userDoc.data();
      const companyData = companyDoc.data();

      console.log("Attempting to send emails to:", {
        userEmail: userData.email,
        companyEmail: companyData.email,
      });

      try {
        await Promise.all([
          transporter
            .sendMail({
              from: '"Up !" <happy.deals59@gmail.com>',
              to: userData.email,
              subject: "Confirmation de votre commande",
              html: generateOrderCustomerEmail(
                pendingOrderData,
                userData,
                orderId
              ),
            })
            .then(() => console.log("Client email sent successfully")),

          transporter
            .sendMail({
              from: '"Up !" <happy.deals59@gmail.com>',
              to: companyData.email,
              subject: "Nouvelle commande reçue",
              html: generateOrderProfessionalEmail(pendingOrderData, userData),
            })
            .then(() => console.log("Company email sent successfully")),
        ]);

        console.log("Both emails sent successfully");
      } catch (emailError) {
        console.error("Error sending emails:", emailError);
      }
    }

    // Programmer la suppression
    if (session.id) {
      // Vérifier que session.id existe
      setTimeout(async () => {
        try {
          await admin
            .firestore()
            .collection("pending_express_deal_payments")
            .doc(session.id)
            .delete();
        } catch (error) {
          console.error("Error deleting pending payment:", error);
        }
      }, 5 * 60 * 1000);
    }

    console.log("Order successfully processed:", orderId);
    return { orderId };
  } catch (error) {
    console.error("Error processing order:", error);
    await admin.firestore().collection("payment_errors").add({
      orderId,
      error: error.message,
      paymentId: session.payment_intent,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    throw error;
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

  const batch = admin.firestore().batch();

  // Générer un code de validation de 6 caractères (lettres et chiffres)
  const generateValidationCode = () => {
    const characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    let code = "";
    for (let i = 0; i < 6; i++) {
      code += characters.charAt(Math.floor(Math.random() * characters.length));
    }
    return code;
  };

  // Créer la réservation
  const reservationRef = admin
    .firestore()
    .collection("reservations")
    .doc(reservationId);
  batch.set(reservationRef, {
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
    isValidated: false,
    basketType: metadata.basketType,
    companyName: metadata.companyName,
    pickupAddress: metadata.pickupAddress,
    validationCode: generateValidationCode(),
  });

  // Mettre à jour le compteur de paniers
  const dealRef = admin.firestore().collection("posts").doc(dealId);
  batch.update(dealRef, {
    basketCount: admin.firestore.FieldValue.increment(-1),
  });

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

  await batch.commit();

  return { reservationId: reservationRef.id };
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

  const bookingRef = admin.firestore().collection("bookings").doc(bookingId);
  await bookingRef.set({
    serviceId: serviceId,
    status: "confirmed",
    paymentId: paymentData.id,
    userId: metadata.userId,
    professionalId: metadata.professionalId,
    bookingDateTime: timestamp,
    amount: parseFloat(metadata.amount || "0"),
    serviceName: metadata.serviceName,
    duration: metadata.duration,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    adresse: metadata.adresse,
  });

  // Programmer la suppression pour plus tard
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
  }, 5 * 60 * 1000); // Supprime après 5 minutes

  return { bookingId: bookingRef.id };
}

async function createPaymentNotification({
  type,
  paymentId,
  metadata,
  result,
}) {
  const notificationRef = admin.firestore().collection("notifications").doc();

  const notificationData = {
    type: `payment_${type}_success`,
    userId: metadata.userId,
    title: getNotificationTitle(type),
    message: getNotificationMessage(type, result),
    relatedId: result.orderId || result.reservationId || result.bookingId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    read: false,
  };

  await notificationRef.set(notificationData);
}

function getNotificationTitle(type) {
  switch (type) {
    case "order":
      return "Commande confirmée";
    case "express_deal":
      return "Réservation express confirmée";
    case "service":
      return "Réservation de service confirmée";
    default:
      return "Paiement confirmé";
  }
}

function getNotificationMessage(type, result) {
  switch (type) {
    case "order":
      return `Votre commande #${result.orderId} a été confirmée`;
    case "express_deal":
      return "Votre réservation express a été confirmée";
    case "service":
      return "Votre réservation de service a été confirmée";
    default:
      return "Votre paiement a été confirmé";
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

// Template pour la confirmation de service (client)
function generateServiceCustomerEmail(orderData, customer) {
  const content = `
    <h1>🎉 Réservation confirmée !</h1>
    <p>Bonjour ${customer.firstName},</p>
    <p>Super ! Votre réservation a été confirmée avec succès.</p>
    
    <div class="details-card">
      <h2>📅 Détails de votre réservation</h2>
      <ul>
        <li><strong>Service :</strong> ${orderData.serviceName}</li>
        <li><strong>Date :</strong> ${new Date(
          orderData.bookingDateTime
        ).toLocaleString("fr-FR", {
          weekday: "long",
          year: "numeric",
          month: "long",
          day: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        })}</li>
        <li><strong>Durée :</strong> ${orderData.duration} minutes</li>
        <li><strong>Adresse :</strong> ${orderData.adresse}</li>
      </ul>
      <div class="price">
        ${(orderData.amount / 100).toFixed(2)}€
      </div>
    </div>

    <div class="highlight">
      <p>🎯 Prochaine étape : Rendez-vous à l'adresse indiquée à l'heure de votre réservation.</p>
    </div>

    <a href="https://votre-site.com/reservations/${
      orderData.id
    }" class="button">
      Voir ma réservation
    </a>

    <p>Des questions ? Nous sommes là pour vous aider !</p>
  `;

  return getBaseEmailTemplate(content);
}

// Template pour la notification au professionnel
function generateServiceProfessionalEmail(orderData, customer) {
  const content = `
    <h1>💫 Nouvelle réservation !</h1>
    <p>Une nouvelle réservation vient d'être confirmée.</p>
    
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
        <li><strong>Service :</strong> ${orderData.serviceName}</li>
        <li><strong>Date :</strong> ${new Date(
          orderData.bookingDateTime
        ).toLocaleString("fr-FR", {
          weekday: "long",
          year: "numeric",
          month: "long",
          day: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        })}</li>
        <li><strong>Durée :</strong> ${orderData.duration} minutes</li>
      </ul>
      <div class="price">
        ${(orderData.amount / 100).toFixed(2)}€
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

// Template pour la commande classique (client)
function generateOrderCustomerEmail(orderData, customer, orderId) {
  const itemsList = orderData.items
    .map(
      (item) => `
    <li style="display: flex; justify-content: space-between; padding: 10px 0;">
      <span>${item.name} x ${item.quantity} </span>
      <span>${item.appliedPrice.toFixed(2)} €</span>
    </li>
  `
    )
    .join("");

  const content = `
    <h1>🛍️ Commande confirmée !</h1>
    <p>Bonjour ${customer.firstName},</p>
    <p>Merci pour votre commande ! Nous avons bien reçu votre paiement.</p>
    
    <div class="details-card">
      <h2>📦 Détails de votre commande</h2>
      <ul>
        ${itemsList}
      </ul>
      <div style="border-top: 2px solid #eee; margin-top: 15px; padding-top: 15px;">
        <div class="price">
          Total : ${orderData.totalPrice.toFixed(2)} €
        </div>
      </div>
    </div>

    <div class="highlight">
      <p>📬 Votre commande sera bientôt préparée.</p>
      <p>Numéro de commande : #${orderId.substring(0, 8)}</p>
    </div>

    <a href="https://valentinlpka.github.io/happydeals/#/commandes/${orderId}" class="button">
      Suivre ma commande
    </a>
  `;

  return getBaseEmailTemplate(content);
}

// Template pour la commande classique (professionnel)
function generateOrderProfessionalEmail(orderData, customer) {
  const itemsList = orderData.items
    .map(
      (item) => `
    <li style="display: flex; justify-content: space-between; padding: 10px 0;">
      <span>${item.name} x${item.quantity}</span>
      <span>${(item.price / 100).toFixed(2)}€</span>
    </li>
  `
    )
    .join("");

  const content = `
    <h1>🎯 Nouvelle commande reçue !</h1>
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
        Total : ${(orderData.amount / 100).toFixed(2)}€
      </div>
    </div>

    <a href="https://votre-site.com/pro/commandes/${
      orderData.id
    }" class="button">
      Gérer la commande
    </a>
  `;

  return getBaseEmailTemplate(content);
}

// Template pour le deal express (client)
function generateDealCustomerEmail(orderData, customer) {
  const content = `
    <h1>🌱 Panier anti-gaspi réservé !</h1>
    <p>Bonjour ${customer.firstName},</p>
    <p>Votre panier anti-gaspi a été réservé avec succès. Merci de contribuer à la lutte contre le gaspillage alimentaire !</p>
    
    <div class="details-card">
      <h2>🛒 Détails de votre panier</h2>
      <ul>
        <li><strong>Type de panier :</strong> ${orderData.basketType}</li>
        <li><strong>À récupérer le :</strong> ${new Date(
          orderData.pickupDate
        ).toLocaleString("fr-FR", {
          weekday: "long",
          year: "numeric",
          month: "long",
          day: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        })}</li>
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

    <a href="https://votre-site.com/reservations/${
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
    <h1>🌟 Nouveau panier anti-gaspi réservé !</h1>
    <p>Un client vient de réserver un panier anti-gaspi.</p>
    
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
