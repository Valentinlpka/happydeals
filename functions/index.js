const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { log } = require("firebase-functions/logger");
const stripe = require("stripe")(functions.config().stripe.secret_key);
const stripeWebhooks = functions.config().stripe.webhooks || {};

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

exports.createPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated."
    );
  }

  const { amount, currency, cartId, userId, isWeb, successUrl, cancelUrl } =
    data;

  try {
    // Vérifier que le panier existe et n'est pas expiré
    const cartDoc = await admin
      .firestore()
      .collection("carts")
      .doc(cartId)
      .get();

    if (!cartDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Cart not found");
    }

    const cartData = cartDoc.data();
    const expiresAt = cartData.expiresAt.toDate();

    if (Date.now() > expiresAt) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Cart has expired"
      );
    }

    // Récupérer ou créer le client Stripe
    let customer;
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(userId)
      .get();
    const userData = userDoc.data();

    if (userData && userData.stripeCustomerId) {
      customer = await stripe.customers.retrieve(userData.stripeCustomerId);
    } else {
      customer = await stripe.customers.create({
        metadata: { firebaseUID: userId },
      });
      await admin.firestore().collection("users").doc(userId).update({
        stripeCustomerId: customer.id,
      });
    }

    // Créer les line items à partir des articles du panier
    const lineItems = cartData.items.map((item) => ({
      price_data: {
        currency: currency,
        unit_amount: Math.round(item.appliedPrice * 100),
        product_data: {
          name: item.name,
          images: item.imageUrl ? [item.imageUrl[0]] : [],
        },
      },
      quantity: item.quantity,
    }));

    const calculateFinalAmount = (cartData) => {
      const subtotal = cartData.items.reduce(
        (sum, item) => sum + item.appliedPrice * item.quantity,
        0
      );
      const discount = cartData.discountAmount || 0;
      return Math.max(0, subtotal - discount);
    };

    if (isWeb) {
      // Pour le web, créer un seul line item avec le montant final
      const finalAmount = calculateFinalAmount(cartData);
      const session = await stripe.checkout.sessions.create({
        payment_method_types: ["card"],
        line_items: [
          {
            price_data: {
              currency: currency,
              unit_amount: Math.round(finalAmount * 100),
              product_data: {
                name: "Commande Happy Deals",
                description: cartData.appliedPromoCode
                  ? `Code promo appliqué: ${cartData.appliedPromoCode}`
                  : undefined,
              },
            },
            quantity: 1,
          },
        ],
        mode: "payment",
        success_url: `${successUrl}?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: cancelUrl,
        customer: customer.id,
        metadata: {
          cartId: cartId,
          appliedPromoCode: cartData.appliedPromoCode || "",
          originalAmount: String(cartData.total || 0),
          discountAmount: String(cartData.discountAmount || 0),
        },
      });

      await cartDoc.ref.update({
        stripeSessionId: session.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { sessionId: session.id, url: session.url };
    } else {
      // Pour mobile, utiliser le montant déjà calculé
      const paymentIntent = await stripe.paymentIntents.create({
        amount, // Le montant est déjà en centimes et calculé côté client
        currency,
        customer: customer.id,
        metadata: {
          cartId: cartId,
          appliedPromoCode: cartData.appliedPromoCode || "",
          originalAmount: String(cartData.total || 0),
          discountAmount: String(cartData.discountAmount || 0),
        },
      });

      await cartDoc.ref.update({
        stripePaymentIntentId: paymentIntent.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { clientSecret: paymentIntent.client_secret };
    }
  } catch (error) {
    console.error("Error creating payment:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// exports.createPayment = functions.https.onCall(async (data, context) => {
//   if (!context.auth) {
//     throw new functions.https.HttpsError(
//       "unauthenticated",
//       "User must be authenticated."
//     );
//   }

//   const {
//     amount,
//     currency,
//     sellerId,
//     userId,
//     isWeb,
//     successUrl,
//     cancelUrl,
//     cartItems,
//   } = data;

//   try {
//     let customer;
//     const userDoc = await admin
//       .firestore()
//       .collection("users")
//       .doc(userId)
//       .get();
//     const userData = userDoc.data();

//     if (userData && userData.stripeCustomerId) {
//       customer = await stripe.customers.retrieve(userData.stripeCustomerId);
//     } else {
//       customer = await stripe.customers.create({
//         metadata: { firebaseUID: userId },
//       });
//       await admin.firestore().collection("users").doc(userId).update({
//         stripeCustomerId: customer.id,
//       });
//     }

//     const lineItems = await Promise.all(
//       cartItems.map(async (item) => {
//         const productDoc = await admin
//           .firestore()
//           .collection("products")
//           .doc(item.productId)
//           .get();
//         const productData = productDoc.data();
//         const appliedPrice =
//           productData.hasActiveHappyDeal && productData.discountedPrice
//             ? productData.discountedPrice
//             : productData.price;

//         return {
//           price_data: {
//             currency: currency,
//             unit_amount: Math.round(appliedPrice * 100),
//             product_data: {
//               name: productData.name,
//             },
//           },
//           quantity: item.quantity,
//         };
//       })
//     );

//     if (isWeb) {
//       const session = await stripe.checkout.sessions.create({
//         payment_method_types: ["card"],
//         line_items: lineItems,
//         mode: "payment",
//         success_url: successUrl,
//         cancel_url: cancelUrl,
//         customer: customer.id,
//       });

//       return { sessionId: session.id, url: session.url };
//     } else {
//       const paymentIntent = await stripe.paymentIntents.create({
//         amount,
//         currency,
//         customer: customer.id,
//       });

//       return { clientSecret: paymentIntent.client_secret };
//     }
//   } catch (error) {
//     console.error("Error creating payment:", error);
//     throw new functions.https.HttpsError("internal", error.message);
//   }
// });

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
//demande d'un paiement de la part d'un pro

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

// Transfert automatique vers le compte du marchand
// exports.transferFunds = functions.firestore
//   .document("orders/{orderId}")
//   .onUpdate(async (change, context) => {
//     const newValue = change.after.data();
//     const previousValue = change.before.data();

//     if (
//       newValue.status === "completed" &&
//       previousValue.status !== "completed"
//     ) {
//       const merchantId = newValue.merchantId;
//       const amount = newValue.amount;

//       const transfer = await stripe.transfers.create({
//         amount: Math.round(amount * 0.9), // 90% du montant (10% de frais)
//         currency: "eur",
//         destination: merchantId,
//       });

//       return change.after.ref.update({ transferId: transfer.id });
//     }

//     return null;
//   });

// functions/index.js
exports.createProduct = functions.https.onCall(async (data, context) => {
  console.log("Début de la fonction createProduct");
  console.log("Données reçues:", JSON.stringify(data));

  if (!context.auth) {
    console.log("Erreur: Utilisateur non authentifié");
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  try {
    console.log("Récupération des données utilisateur");
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

    if (!data.name || typeof data.name !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Le nom du produit est requis et doit être une chaîne de caractères"
      );
    }

    if (!data.price || typeof data.price !== "number" || data.price <= 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Le prix du produit est requis et doit être un nombre positif"
      );
    }

    console.log("Création du produit Stripe");
    const stripeProduct = await stripe.products.create(
      {
        name: data.name,
        description: data.description || "",
      },
      {
        stripeAccount: stripeAccountId,
      }
    );
    console.log("Produit Stripe créé:", stripeProduct.id);

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

    console.log("Ajout du produit à Firestore");

    const productRef = admin.firestore().collection("products").doc(); // Créer d'abord la référence
    const productId = productRef.id; // Obtenir l'ID

    await productRef.set({
      name: data.name,
      description: data.description || "",
      price: data.price,
      tva: data.tva,
      stock: data.stock,
      images: data.images,
      isActive: data.isActive,
      sellerId: data.sellerId,
      stripeProductId: stripeProduct.id,
      stripePriceId: stripePrice.id,
      merchantId: stripeAccountId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log("Produit ajouté à Firestore:", productRef.id);

    return {
      success: true,
      productId: productId,
      stripeProductId: stripeProduct.id,
      stripePriceId: stripePrice.id,
    };
  } catch (error) {
    console.error("Erreur détaillée:", error);
    throw new functions.https.HttpsError(
      "internal",
      `Impossible de créer le produit: ${error.message}`
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

// Ajoutez ces fonctions à votre fichier index.js existant

// Modification d'un article
exports.updateProduct = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  const { productId, name, description, price, images, isActive, stock } = data;

  try {
    const productRef = admin.firestore().collection("products").doc(productId);
    const product = await productRef.get();

    if (!product.exists) {
      throw new functions.https.HttpsError("not-found", "Produit non trouvé");
    }

    // Mise à jour dans Firestore
    await productRef.update({
      name,
      description,
      price,
      images,
      isActive,
      stock,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Mise à jour dans Stripe
    await stripe.products.update(
      product.data().stripeProductId,
      {
        name,
        description,
        images,
        active: isActive,
        metadata: { stock: stock.toString() },
      },
      {
        stripeAccount: product.data().merchantId,
      }
    );

    await stripe.prices.update(
      product.data().stripePriceId,
      {
        active: isActive,
      },
      {
        stripeAccount: product.data().merchantId,
      }
    );

    return { success: true, productId };
  } catch (error) {
    console.error("Erreur lors de la mise à jour du produit:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Impossible de mettre à jour le produit"
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

// Ajoutez ces fonctions à votre fichier index.js existant

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

// Dans votre fichier index.js des fonctions Cloud

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

exports.createOrder = functions.https.onCall(async (data, context) => {
  // Vérifier si l'utilisateur est authentifié
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié pour créer une commande."
    );
  }

  const {
    sellerId,
    items,
    subtotal,
    happyDealSavings,
    promoCode,
    discountAmount,
    totalPrice,
    pickupAddress,
    entrepriseId,
  } = data;

  try {
    // Créer la commande dans Firestore
    const orderRef = await admin.firestore().collection("orders").add({
      userId: context.auth.uid,
      sellerId,
      entrepriseId,
      items,
      subtotal,
      happyDealSavings,
      promoCode,
      discountAmount,
      totalPrice,
      pickupAddress,
      status: "paid", // Ou 'pending', selon votre logique de paiement
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Vous pouvez ajouter ici d'autres logiques, comme mettre à jour le stock des produits

    console.log(`Commande créée avec succès. ID: ${orderRef.id}`);
    return { orderId: orderRef.id };
  } catch (error) {
    console.error("Erreur lors de la création de la commande:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Impossible de créer la commande: " + error.message
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

exports.createPaymentAndReservation = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "L'utilisateur doit être authentifié."
      );
    }

    const { dealId, amount, currency, isWeb, successUrl, cancelUrl } = data;

    try {
      // Récupérer les informations de l'utilisateur
      const userDoc = await admin
        .firestore()
        .collection("users")
        .doc(context.auth.uid)
        .get();
      const userData = userDoc.data();

      // Récupérer les informations du deal
      const dealDoc = await admin
        .firestore()
        .collection("posts")
        .doc(dealId)
        .get();
      const dealData = dealDoc.data();

      if (!dealData) {
        throw new functions.https.HttpsError("not-found", "Deal non trouvé");
      }

      // Créer ou récupérer le client Stripe
      let customer;
      if (userData.stripeCustomerId) {
        customer = await stripe.customers.retrieve(userData.stripeCustomerId);
      } else {
        customer = await stripe.customers.create({
          email: userData.email,
          metadata: { firebaseUID: context.auth.uid },
        });
        await admin
          .firestore()
          .collection("users")
          .doc(context.auth.uid)
          .update({
            stripeCustomerId: customer.id,
          });
      }

      let paymentIntent;

      if (isWeb) {
        // Pour les paiements web, créer une session de paiement
        const session = await stripe.checkout.sessions.create({
          payment_method_types: ["card"],
          line_items: [
            {
              price_data: {
                currency: currency,
                unit_amount: amount,
                product_data: {
                  name: dealData.basketType,
                },
              },
              quantity: 1,
            },
          ],
          mode: "payment",
          success_url: successUrl,
          cancel_url: cancelUrl,
          customer: customer.id,
          payment_intent_data: {
            transfer_data: {
              destination: dealData.stripeAccountId,
            },
          },
        });

        return {
          sessionId: session.id,
          url: session.url,
          clientSecret: paymentIntent.client_secret,
          paymentIntentId: paymentIntent.id,
        };
      } else {
        // Pour les paiements mobiles, créer une intention de paiement
        paymentIntent = await stripe.paymentIntents.create({
          amount,
          currency,
          customer: customer.id,
          transfer_data: { destination: dealData.stripeAccountId },
        });

        return {
          clientSecret: paymentIntent.client_secret,
          paymentIntentId: paymentIntent.id,
        };
      }
    } catch (error) {
      console.error("Erreur lors de la création du paiement:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

// exports.confirmReservation = functions.https.onCall(async (data, context) => {
//   if (!context.auth) {
//     throw new functions.https.HttpsError(
//       "unauthenticated",
//       "L'utilisateur doit être authentifié."
//     );
//   }

//   const { dealId, paymentIntentId } = data;

//   try {
//     // Vérifier le statut du paiement
//     const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

//     if (paymentIntent.status !== "succeeded") {
//       throw new functions.https.HttpsError(
//         "failed-precondition",
//         "Le paiement n'a pas été effectué avec succès."
//       );
//     }

//     // Récupérer les informations du deal
//     const dealDoc = await admin
//       .firestore()
//       .collection("posts")
//       .doc(dealId)
//       .get();
//     const dealData = dealDoc.data();

//     if (!dealData) {
//       throw new functions.https.HttpsError("not-found", "Deal non trouvé");
//     }

//     // Générer un code de validation
//     const validationCode = Math.random()
//       .toString(36)
//       .substr(2, 6)
//       .toUpperCase();

//     const companyDoc = await admin
//       .firestore()
//       .collection("companys")
//       .doc(dealData.companyId)
//       .get();

//     const companyData = companyDoc.data();

//     const adress = companyData.adress;
//     const addressParts = [
//       adress.adresse,
//       adress.code_postal,
//       adress.ville,
//       adress.pays,
//     ].filter(Boolean);

//     // Créer la réservation
//     const reservation = {
//       buyerId: context.auth.uid,
//       postId: dealId,
//       companyId: dealData.companyId,
//       basketType: dealData.basketType,
//       price: dealData.price,
//       pickupDate: dealData.pickupTime,
//       isValidated: false,
//       paymentIntentId: paymentIntentId,
//       validationCode: validationCode,
//       quantity: 1,
//       companyName: companyData.name,
//       pickupAddress: addressParts.join(", "),
//       timestamp: admin.firestore.FieldValue.serverTimestamp(),
//     };

//     const reservationRef = await admin
//       .firestore()
//       .collection("reservations")
//       .add(reservation);

//     // Mettre à jour le nombre de paniers disponibles
//     await admin
//       .firestore()
//       .collection("posts")
//       .doc(dealId)
//       .update({
//         basketCount: admin.firestore.FieldValue.increment(-1),
//       });

//     return {
//       success: true,
//       reservationId: reservationRef.id,
//       validationCode: validationCode,
//     };
//   } catch (error) {
//     console.error("Erreur lors de la confirmation de la réservation:", error);
//     throw new functions.https.HttpsError("internal", error.message);
//   }
// });

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

exports.createExpressDealPayment = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "L'utilisateur doit être authentifié."
      );
    }

    try {
      const { dealId, pickupTime, successUrl, cancelUrl } = data;

      // Récupérer les détails du deal
      const dealDoc = await admin
        .firestore()
        .collection("posts")
        .doc(dealId)
        .get();

      if (!dealDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Deal non trouvé");
      }

      const dealData = dealDoc.data();

      // Créer la session de paiement
      const session = await stripe.checkout.sessions.create({
        mode: "payment",
        success_url: `${successUrl}?session_id={CHECKOUT_SESSION_ID}`,
        cancel_url: cancelUrl,
        payment_method_types: ["card"],
        client_reference_id: context.auth.uid,
        line_items: [
          {
            price_data: {
              currency: "eur",
              unit_amount: dealData.price * 100,
              product_data: {
                name: dealData.title,
                description: dealData.content,
              },
            },
            quantity: 1,
          },
        ],
        metadata: {
          type: "express_deal",
          dealId: dealId,
          dealTitle: dealData.title,
          userId: context.auth.uid,
          merchantId: dealData.companyId,
          pickupTime: pickupTime,
        },
      });

      return {
        sessionId: session.id,
        sessionUrl: session.url,
      };
    } catch (error) {
      console.error("Erreur création paiement:", error);
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

// Webhook pour gérer le succès du paiement
exports.handleExpressDealPayment = functions.https.onRequest(
  async (request, response) => {
    const sig = request.headers["stripe-signature"];
    let event;

    try {
      event = stripe.webhooks.constructEvent(
        request.rawBody,
        sig,
        functions.config().stripe.webhook_secret
      );
    } catch (err) {
      response.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    if (event.type === "checkout.session.completed") {
      const session = event.data.object;

      if (session.metadata.type === "express_deal") {
        try {
          const dealId = session.metadata.dealId;
          const pickupTime = session.metadata.pickupTime;

          // Mettre à jour le stock du deal
          await admin
            .firestore()
            .collection("posts")
            .doc(dealId)
            .update({
              basketCount: admin.firestore.FieldValue.increment(-1),
            });

          // Créer la réservation
          await admin
            .firestore()
            .collection("reservations")
            .add({
              dealId: dealId,
              userId: session.client_reference_id,
              pickupTime: admin.firestore.Timestamp.fromDate(
                new Date(pickupTime)
              ),
              status: "confirmed",
              stripeSessionId: session.id,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        } catch (error) {
          console.error("Erreur lors du traitement du paiement:", error);
        }
      }
    }

    response.json({ received: true });
  }
);

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

// Dans votre index.js des Cloud Functions
exports.stripeWebhook = functions.https.onRequest(async (request, response) => {
  if (request.method !== "POST") {
    response.status(405).send("Method Not Allowed");
    return;
  }

  const sig = request.headers["stripe-signature"];
  const secret = stripeWebhooks.webhook1; // Utilisation de la clé pour webhook1

  let event;

  try {
    event = stripe.webhooks.constructEvent(request.rawBody, sig, secret);

    console.log("Webhook reçu:", event.type);

    switch (event.type) {
      case "checkout.session.completed":
        await handleCheckoutSessionCompleted(event.data.object);
        break;
      case "payment_intent.succeeded":
        await handlePaymentIntentSucceeded(event.data.object);
        break;
      case "payment_intent.payment_failed":
        await handlePaymentIntentFailed(event.data.object);
        break;
      default:
        console.log(`Type d'événement non géré: ${event.type}`);
    }

    response.json({ received: true });
  } catch (err) {
    console.error("Erreur webhook:", err.message);
    response.status(400).send(`Webhook Error: ${err.message}`);
  }
});

async function handleCheckoutSessionCompleted(session) {
  console.log("Traitement checkout session:", session.id);

  if (session.metadata?.type !== "express_deal") {
    console.log("Pas un express deal, ignoré");
    return;
  }

  try {
    const dealId = session.metadata.dealId;
    const userId = session.metadata.userId;
    const pickupTime = new Date(session.metadata.pickupTime);
    const validationCode = generateValidationCode();

    await admin.firestore().runTransaction(async (transaction) => {
      // Vérifier le stock disponible
      const dealRef = admin.firestore().collection("posts").doc(dealId);
      const dealDoc = await transaction.get(dealRef);

      if (!dealDoc.exists) {
        throw new Error("Deal non trouvé");
      }

      const dealData = dealDoc.data();
      if (dealData.basketCount <= 0) {
        throw new Error("Plus de stock disponible");
      }

      // Récupérer les informations de l'entreprise
      const companyDoc = await transaction.get(
        admin.firestore().collection("companys").doc(dealData.companyId)
      );
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

      // Créer la réservation
      const reservationRef = admin.firestore().collection("reservations").doc();
      transaction.set(reservationRef, {
        dealId: dealId,
        userId: userId,
        sessionId: session.id,
        amount: session.amount_total / 100,
        validationCode: validationCode,
        pickupTime: admin.firestore.Timestamp.fromDate(pickupTime),
        status: "confirmed",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        buyerId: userId,
        postId: dealId,
        companyId: dealData.companyId,
        basketType: dealData.basketType,
        price: appliedPrice,
        originalPrice: dealData.price,
        discountAmount: dealData.hasActiveHappyDeal
          ? dealData.price - appliedPrice
          : 0,
        pickupDate: admin.firestore.Timestamp.fromDate(pickupTime),
        isValidated: false,
        paymentIntentId: session.payment_intent,
        quantity: 1,
        companyName: companyData.name,
        pickupAddress: addressParts.join(", "),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Mettre à jour le stock
      transaction.update(dealRef, {
        basketCount: admin.firestore.FieldValue.increment(-1),
      });

      // Créer la notification
      const notificationRef = admin
        .firestore()
        .collection("notifications")
        .doc();
      transaction.set(notificationRef, {
        userId: session.metadata.merchantId,
        type: "new_reservation",
        title: "Nouvelle réservation",
        message: `Un client a réservé le deal ${session.metadata.dealTitle}`,
        reservationId: reservationRef.id,
        read: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        reservationId: reservationRef.id,
        validationCode: validationCode,
      };
    });

    console.log("Transaction complétée avec succès");
  } catch (error) {
    console.error("Erreur lors du traitement de la réservation:", error);
    throw error;
  }
}

async function handlePaymentIntentSucceeded(paymentIntent) {
  console.log("Paiement réussi:", paymentIntent.id);

  if (!paymentIntent.metadata.dealId) return;

  try {
    // Mettre à jour le statut de paiement
    const reservations = await admin
      .firestore()
      .collection("reservations")
      .where("paymentIntentId", "==", paymentIntent.id)
      .get();

    for (const doc of reservations.docs) {
      await doc.ref.update({
        paymentStatus: "succeeded",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  } catch (error) {
    console.error("Erreur mise à jour du statut de paiement:", error);
  }
}

async function handlePaymentIntentFailed(paymentIntent) {
  console.log("Paiement échoué:", paymentIntent.id);

  if (!paymentIntent.metadata.dealId) return;

  try {
    // Mettre à jour le statut de paiement et libérer le stock si nécessaire
    const reservations = await admin
      .firestore()
      .collection("reservations")
      .where("paymentIntentId", "==", paymentIntent.id)
      .get();

    for (const doc of reservations.docs) {
      await doc.ref.update({
        paymentStatus: "failed",
        status: "cancelled",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Réincrémenter le stock
      await admin
        .firestore()
        .collection("posts")
        .doc(paymentIntent.metadata.dealId)
        .update({
          basketCount: admin.firestore.FieldValue.increment(1),
        });
    }
  } catch (error) {
    console.error("Erreur mise à jour du statut de paiement:", error);
  }
}

function generateValidationCode() {
  return Math.random().toString(36).substring(2, 8).toUpperCase();
}

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

// Cloud Function pour créer une session de paiement Stripe
exports.createServicePaymentWeb = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Vous devez être connecté pour effectuer cette action"
      );
    }

    try {
      // Récupérer le service
      const serviceDoc = await admin
        .firestore()
        .collection("services")
        .doc(data.serviceId)
        .get();

      if (!serviceDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Service non trouvé");
      }

      const serviceData = serviceDoc.data();

      // Récupérer le créneau
      const timeSlotDoc = await admin
        .firestore()
        .collection("timeSlots")
        .doc(data.timeSlotId)
        .get();

      if (!timeSlotDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Créneau non trouvé");
      }

      const timeSlotData = timeSlotDoc.data();

      // Créer la description du service
      const description = `Réservation pour le ${timeSlotData.date
        .toDate()
        .toLocaleDateString()} à ${timeSlotData.startTime
        .toDate()
        .toLocaleTimeString()}`;

      // Créer la session de paiement Stripe
      const session = await stripe.checkout.sessions.create({
        payment_method_types: ["card"],
        mode: "payment",
        success_url: data.successUrl,
        cancel_url: data.cancelUrl,
        line_items: [
          {
            price_data: {
              currency: "eur",
              unit_amount: data.amount,
              product_data: {
                name: serviceData.name,
                description: description,
              },
            },
            quantity: 1,
          },
        ],
        metadata: {
          serviceId: data.serviceId,
          timeSlotId: data.timeSlotId,
          userId: context.auth.uid,
          date: timeSlotData.date.toDate().toISOString(),
          startTime: timeSlotData.startTime.toDate().toISOString(),
          endTime: timeSlotData.endTime.toDate().toISOString(),
        },
        customer_email: context.auth.token.email,
      });

      return {
        url: session.url,
        sessionId: session.id,
      };
    } catch (error) {
      console.error(
        "Erreur lors de la création de la session de paiement:",
        error
      );
      throw new functions.https.HttpsError("internal", error.message);
    }
  }
);

// Webhook pour gérer le succès du paiement
exports.handleStripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers["stripe-signature"];
  const secret = stripeWebhooks.webhook2; // Utilisation de la clé pour webhook1

  let event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, secret);
  } catch (err) {
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  if (event.type === "checkout.session.completed") {
    const session = event.data.object;

    try {
      // Récupérer le timeSlot pour obtenir la date de réservation
      const timeSlotDoc = await admin
        .firestore()
        .collection("timeSlots")
        .doc(session.metadata.timeSlotId)
        .get();

      const timeSlotData = timeSlotDoc.data();
      // Mettre à jour le créneau horaire
      await admin
        .firestore()
        .collection("timeSlots")
        .doc(session.metadata.timeSlotId)
        .update({
          isAvailable: false,
          bookedByUserId: session.metadata.userId,
        });

      // Créer la réservation
      await admin
        .firestore()
        .collection("bookings")
        .add({
          serviceId: session.metadata.serviceId,
          timeSlotId: session.metadata.timeSlotId,
          userId: session.metadata.userId,
          status: "confirmed",
          amount: session.amount_total / 100,
          stripeSessionId: session.id,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          bookingDate: timeSlotData.startTime, // Ajouter la date de réservation
        });
    } catch (error) {
      console.error("Erreur lors du traitement du paiement:", error);
    }
  }

  res.json({ received: true });
});
