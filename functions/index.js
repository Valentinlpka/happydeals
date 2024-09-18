const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { log } = require("firebase-functions/logger");
const stripe = require("stripe")(functions.config().stripe.secret_key);

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

// Création d'un paiement
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
//     connectAccountId,
//     userId,
//     isWeb,
//     successUrl,
//     cancelUrl,
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

// if (isWeb) {
//   // Pour les paiements web, créer une session de paiement
//   const session = await stripe.checkout.sessions.create({
//     payment_method_types: ["card"],
//     line_items: [
//       {
//         price_data: {
//           currency: currency,
//           unit_amount: amount,
//           product_data: {
//             name: "Achat sur Happy Deals",
//           },
//         },
//         quantity: 1,
//       },
//     ],
//     mode: "payment",
//     success_url: successUrl,
//     cancel_url: cancelUrl,
//     customer: customer.id,
//     payment_intent_data: {
//       transfer_data: {
//         destination: connectAccountId,
//       },
//     },
//   });

//   return { sessionId: session.id, url: session.url };
// } else {
//   // Pour les paiements mobiles, créer une intention de paiement
//   const paymentIntent = await stripe.paymentIntents.create({
//     amount,
//     currency,
//     customer: customer.id,
//     transfer_data: { destination: connectAccountId },
//   });

//   return { clientSecret: paymentIntent.client_secret };
// }
//   } catch (error) {
//     console.error("Error creating payment:", error);
//     throw new functions.https.HttpsError("internal", error.message);
//   }
// });

exports.createPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated."
    );
  }

  const { amount, currency, sellerId, userId, isWeb, successUrl, cancelUrl } =
    data;

  try {
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

    if (isWeb) {
      const session = await stripe.checkout.sessions.create({
        payment_method_types: ["card"],
        line_items: [
          {
            price_data: {
              currency: currency,
              unit_amount: amount,
              product_data: {
                name: "Achat sur Happy Deals",
              },
            },
            quantity: 1,
          },
        ],
        mode: "payment",
        success_url: successUrl,
        cancel_url: cancelUrl,
        customer: customer.id,
      });

      return { sessionId: session.id, url: session.url };
    } else {
      const paymentIntent = await stripe.paymentIntents.create({
        amount,
        currency,
        customer: customer.id,
      });

      return { clientSecret: paymentIntent.client_secret };
    }
  } catch (error) {
    console.error("Error creating payment:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
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
      const amount = newValue.totalPrice;

      try {
        // Recherche de l'entreprise correspondante dans la collection "Companys"
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

        // Mise à jour du solde de l'entreprise
        await admin
          .firestore()
          .collection("companys")
          .doc(companyId)
          .update({
            availableBalance: admin.firestore.FieldValue.increment(amount),
          });

        // Enregistrement de la transaction
        await admin.firestore().collection("transactions").add({
          companyId: companyId,
          orderId: context.params.orderId,
          amount: amount,
          type: "credit",
          status: "pending",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(
          `Solde mis à jour pour l'entreprise: ${companyId}, Montant: ${amount}`
        );
      } catch (error) {
        console.error("Erreur lors de la mise à jour du solde:", error);
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
    const balance = await stripe.balance.retrieve();
    const availableBalance =
      balance.available.find((bal) => bal.currency === "eur")?.amount || 0;
    console.log(availableBalance);

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
      console.log(companyData.userUid);
      console.log(userUid);
      throw new functions.https.HttpsError(
        "permission-denied",
        "Vous n'avez pas les droits pour cette entreprise"
      );
    }

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
    const productRef = await admin
      .firestore()
      .collection("products")
      .add({
        name: data.name,
        description: data.description || "",
        price: data.price,
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
      productId: productRef.id,
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

  const { sellerId, items, totalPrice, pickupAddress } = data;

  try {
    // Créer la commande dans Firestore
    const orderRef = await admin.firestore().collection("orders").add({
      userId: context.auth.uid,
      sellerId,
      items,
      totalPrice,
      pickupAddress,
      status: "paid", // Ou 'pending', selon votre logique de paiement
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Vous pouvez ajouter ici d'autres logiques, comme mettre à jour le stock des produits

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

exports.confirmReservation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "L'utilisateur doit être authentifié."
    );
  }

  const { dealId, paymentIntentId } = data;

  try {
    // Vérifier le statut du paiement
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    if (paymentIntent.status !== "succeeded") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Le paiement n'a pas été effectué avec succès."
      );
    }

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

    // Générer un code de validation
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

    // Créer la réservation
    const reservation = {
      buyerId: context.auth.uid,
      postId: dealId,
      companyId: dealData.companyId,
      basketType: dealData.basketType,
      price: dealData.price,
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

    // Mettre à jour le nombre de paniers disponibles
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
