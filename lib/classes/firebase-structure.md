# Structure Firestore complète pour l'application sociale et marketplace

Ce document détaille la structure complète des collections et sous-collections Firebase Firestore pour votre application sociale couplée à une marketplace, avec des exemples de documents pour chaque cas d'utilisation.

## Table des matières

1. [Collection Users](#collection-users)
2. [Collection Content](#collection-content)
3. [Collection Subscriptions](#collection-subscriptions)
4. [Collection Interactions](#collection-interactions)
5. [Collection Slots](#collection-slots)
6. [Collection AvailabilityPatterns](#collection-availabilitypatterns)
7. [Collection Transactions](#collection-transactions)
8. [Collection Promotions](#collection-promotions)
9. [Collection UserPromotions](#collection-userpromotions)
10. [Collection Notifications](#collection-notifications)

---

## Collection Users

Stocke tous les utilisateurs, quel que soit leur type.

### Structure

```
users/
  ├─ {userId}/
     ├─ type: "particular" | "professional" | "association"
     ├─ displayName: string
     ├─ email: string
     ├─ phoneNumber: string
     ├─ profilePicture: string (URL)
     ├─ coverPhoto: string (URL)
     ├─ bio: string
     ├─ location: {
        ├─ address: string
        ├─ city: string
        ├─ postalCode: string
        ├─ country: string
        ├─ coordinates: {
           ├─ latitude: number
           ├─ longitude: number
        }
     }
     ├─ createdAt: timestamp
     ├─ updatedAt: timestamp
     ├─ settings: {
        ├─ notifications: boolean
        ├─ privacy: { ... }
     }
     ├─ professionalDetails: { // Pour les professionnels uniquement
        ├─ businessName: string
        ├─ logo: string (URL)
        ├─ siret: string
        ├─ tvaNumber: string
        ├─ juridicForm: string
        ├─ codeAPE: string
        ├─ sector: string
        ├─ subSector: string
        ├─ openingHours: [{ day, open, close }, ...]
        ├─ certifications: [string]
     }
     ├─ associationDetails: { // Pour les associations uniquement
        ├─ associationName: string
        ├─ logo: string (URL)
        ├─ sirenNumber: string
        ├─ rnaNumber: string
        ├─ juridicStructure: string
        ├─ mainAction: string
        ├─ geographicZone: string
     }
     ├─ stripeDetails: {
        ├─ customerId: string
        ├─ accountId: string // Pour les vendeurs
     }
```

### Exemples

#### Exemple d'un particulier

```json
{
  "type": "particular",
  "displayName": "Marie Dupont",
  "email": "marie.dupont@example.com",
  "phoneNumber": "+33612345678",
  "profilePicture": "https://storage.example.com/profiles/marie_dupont.jpg",
  "coverPhoto": "https://storage.example.com/covers/marie_dupont.jpg",
  "bio": "Passionnée de cuisine et de voyages",
  "location": {
    "address": "15 Rue des Fleurs",
    "city": "Valenciennes",
    "postalCode": "59300",
    "country": "France",
    "coordinates": {
      "latitude": 50.3571,
      "longitude": 3.5183
    }
  },
  "createdAt": "2024-10-15T14:30:00Z",
  "updatedAt": "2024-10-15T14:30:00Z",
  "settings": {
    "notifications": true,
    "privacy": {
      "showLocation": true,
      "allowMessages": true
    }
  },
  "stripeDetails": {
    "customerId": "cus_MN2s9aJX1pUTvL"
  }
}
```

#### Exemple d'un professionnel

```json
{
  "type": "professional",
  "displayName": "Boulangerie Martin",
  "email": "contact@boulangerie-martin.fr",
  "phoneNumber": "+33327123456",
  "profilePicture": "https://storage.example.com/profiles/boulangerie_martin.jpg",
  "coverPhoto": "https://storage.example.com/covers/boulangerie_martin.jpg",
  "bio": "Boulangerie artisanale depuis 1985",
  "location": {
    "address": "22 Rue du Commerce",
    "city": "Valenciennes",
    "postalCode": "59300",
    "country": "France",
    "coordinates": {
      "latitude": 50.3562,
      "longitude": 3.5239
    }
  },
  "createdAt": "2024-09-10T09:15:00Z",
  "updatedAt": "2024-10-01T11:20:00Z",
  "settings": {
    "notifications": true,
    "privacy": {
      "showLocation": true,
      "allowMessages": true
    }
  },
  "professionalDetails": {
    "businessName": "Boulangerie Martin SARL",
    "logo": "https://storage.example.com/logos/boulangerie_martin.png",
    "siret": "12345678900012",
    "tvaNumber": "FR12345678900",
    "juridicForm": "SARL",
    "codeAPE": "1071C",
    "sector": "Alimentation",
    "subSector": "Boulangerie",
    "openingHours": [
      { "day": 1, "open": "07:00", "close": "19:30" },
      { "day": 2, "open": "07:00", "close": "19:30" },
      { "day": 3, "open": "07:00", "close": "19:30" },
      { "day": 4, "open": "07:00", "close": "19:30" },
      { "day": 5, "open": "07:00", "close": "19:30" },
      { "day": 6, "open": "07:00", "close": "18:00" },
      { "day": 0, "open": "closed", "close": "closed" }
    ],
    "certifications": ["Artisan certifié", "Label Qualité"]
  },
  "stripeDetails": {
    "customerId": "cus_H72jSnDla0Kmsw",
    "accountId": "acct_1L8dK9PJmRtGX0zM"
  }
}
```

#### Exemple d'une association

```json
{
  "type": "association",
  "displayName": "Les Amis de la Nature",
  "email": "contact@amisdelanature.org",
  "phoneNumber": "+33327987654",
  "profilePicture": "https://storage.example.com/profiles/amis_nature.jpg",
  "coverPhoto": "https://storage.example.com/covers/amis_nature.jpg",
  "bio": "Association de protection de l'environnement local",
  "location": {
    "address": "5 Rue des Jardins",
    "city": "Valenciennes",
    "postalCode": "59300",
    "country": "France",
    "coordinates": {
      "latitude": 50.3593,
      "longitude": 3.5210
    }
  },
  "createdAt": "2024-08-22T10:45:00Z",
  "updatedAt": "2024-10-05T16:30:00Z",
  "settings": {
    "notifications": true,
    "privacy": {
      "showLocation": true,
      "allowMessages": true
    }
  },
  "associationDetails": {
    "associationName": "Les Amis de la Nature - Valenciennes",
    "logo": "https://storage.example.com/logos/amis_nature.png",
    "sirenNumber": "987654321",
    "rnaNumber": "W123456789",
    "juridicStructure": "Association déclarée",
    "mainAction": "environnement",
    "geographicZone": "départemental"
  },
  "stripeDetails": {
    "customerId": "cus_K94sL2pqA7rBtN",
    "accountId": "acct_1M9eR3QKmStHY1zN"
  }
}
```

---

## Collection Content

Stocke tous les types de contenu (posts, produits, services, événements, etc.).

### Structure

```
content/
  ├─ {contentId}/
     ├─ authorId: string (userId)
     ├─ type: "post" | "product" | "service" | "job" | "event" | "deal" | "exchange" | "promo" | "referral" | "fidelity" | "contest" | "professional_service" | "foodService"
     ├─ title: string
     ├─ description: string
     ├─ media: [{ type: "image" | "video", url: string }]
     ├─ createdAt: timestamp
     ├─ updatedAt: timestamp
     ├─ location: {
        ├─ address: string
        ├─ coordinates: { latitude, longitude }
     }
     ├─ visibility: "public" | "followers" | "private"
     ├─ tags: [string]
     ├─ likeCount: number
     ├─ commentCount: number
     ├─ shareCount: number
     ├─ authorName: string  // Dénormalisé pour l'affichage
     ├─ authorLogo: string  // Dénormalisé pour l'affichage
     ├─ displayStatus: "upcoming" | "active" | "expired"
     ├─ validity: {
        ├─ startDate: timestamp
        ├─ endDate: timestamp
        ├─ isRecurring: boolean
        ├─ recurringPattern: {
           ├─ daysOfWeek: [0-6]
           ├─ timeRanges: [{ start: "HH:MM", end: "HH:MM" }]
        }
     }
     ├─ postDetails: { ... } // Détails spécifiques au post simple
     ├─ productDetails: { ... } // Détails spécifiques au produit
     ├─ serviceDetails: { ... } // Détails spécifiques au service
     ├─ eventDetails: { ... } // Détails spécifiques à l'événement
     ├─ jobDetails: { ... } // Détails spécifiques à l'offre d'emploi
     // etc. pour chaque type de contenu
```

### Exemples

#### Exemple d'un post standard

```json
{
  "authorId": "user123",
  "type": "post",
  "title": "Journée au parc",
  "description": "Magnifique journée passée au parc de la Rhônelle. Les couleurs d'automne sont splendides !",
  "media": [
    { "type": "image", "url": "https://storage.example.com/posts/park_photo1.jpg" },
    { "type": "image", "url": "https://storage.example.com/posts/park_photo2.jpg" }
  ],
  "createdAt": "2024-10-16T15:20:00Z",
  "updatedAt": "2024-10-16T15:20:00Z",
  "location": {
    "address": "Parc de la Rhônelle, Valenciennes",
    "coordinates": {
      "latitude": 50.3587,
      "longitude": 3.5194
    }
  },
  "visibility": "public",
  "tags": ["nature", "automne", "valenciennes", "parc"],
  "likeCount": 12,
  "commentCount": 3,
  "shareCount": 1,
  "authorName": "Marie Dupont",
  "authorLogo": "https://storage.example.com/profiles/marie_dupont.jpg",
  "displayStatus": "active",
  "postDetails": {
    "mood": "happy",
    "activity": "promenade"
  }
}
```

#### Exemple d'un produit

```json
{
  "authorId": "business456",
  "type": "product",
  "title": "Baguette Tradition",
  "description": "Notre baguette tradition, fabriquée à l'ancienne avec un levain naturel et une farine Label Rouge. Une croûte croustillante et une mie alvéolée pour le plaisir des gourmets.",
  "media": [
    { "type": "image", "url": "https://storage.example.com/products/baguette_tradition1.jpg" },
    { "type": "image", "url": "https://storage.example.com/products/baguette_tradition2.jpg" }
  ],
  "createdAt": "2024-10-02T08:30:00Z",
  "updatedAt": "2024-10-10T09:15:00Z",
  "location": {
    "address": "22 Rue du Commerce, 59300 Valenciennes",
    "coordinates": {
      "latitude": 50.3562,
      "longitude": 3.5239
    }
  },
  "visibility": "public",
  "tags": ["boulangerie", "pain", "tradition", "artisanal"],
  "likeCount": 27,
  "commentCount": 8,
  "shareCount": 3,
  "authorName": "Boulangerie Martin",
  "authorLogo": "https://storage.example.com/logos/boulangerie_martin.png",
  "displayStatus": "active",
  "productDetails": {
    "brand": "Boulangerie Martin",
    "model": "Tradition",
    "category": "Alimentation",
    "subCategory": "Boulangerie",
    "price": 1.20,
    "vatRate": 5.5,
    "availability": 25,
    "pickupLocation": "22 Rue du Commerce, 59300 Valenciennes",
    "productDetails": "Farine Label Rouge, sel de Guérande, levain maison. Poids moyen: 250g.",
    "reference": "BAG-TRAD-01",
    "warranty": "Garantie de fraîcheur: produit du jour",
    "variants": []
  }
}
```

#### Exemple d'un service

```json
{
  "authorId": "business789",
  "type": "service",
  "title": "Massage californien",
  "description": "Massage californien intégral aux huiles essentielles chaudes, véritable expérience sensorielle et de lâcher-prise. Parfait pour les personnes stressées.",
  "media": [
    { "type": "image", "url": "https://storage.example.com/services/massage_californien.jpg" }
  ],
  "createdAt": "2024-09-25T11:40:00Z",
  "updatedAt": "2024-10-12T10:20:00Z",
  "location": {
    "address": "8 Avenue du Bien-être, 59300 Valenciennes",
    "coordinates": {
      "latitude": 50.3598,
      "longitude": 3.5215
    }
  },
  "visibility": "public",
  "tags": ["massage", "bien-être", "relaxation", "détente", "stress"],
  "likeCount": 19,
  "commentCount": 5,
  "shareCount": 2,
  "authorName": "Espace Zen",
  "authorLogo": "https://storage.example.com/logos/espace_zen.png",
  "displayStatus": "active",
  "serviceDetails": {
    "category": "Bien-être",
    "subCategory": "Massage",
    "price": 65.00,
    "vatRate": 20,
    "duration": 60,
    "executionLocation": "onSite",
    "travelRadius": 0,
    "serviceDescription": "Le massage californien est une approche globale qui vise à réconcilier corps et esprit. Technique de massage utilisant de longs mouvements lents et fluides qui permettent une profonde relaxation physique et psychique.",
    "materialProvided": "Huiles essentielles, serviettes, table de massage chauffante",
    "participantsMin": 1,
    "participantsMax": 1,
    "cancellationPolicy": "Annulation gratuite jusqu'à 24h avant le rendez-vous",
    "availableSlotsPattern": {
      "daysOfWeek": [1, 2, 3, 4, 5],
      "timeSlots": [
        { "start": "10:00", "end": "11:00" },
        { "start": "11:30", "end": "12:30" },
        { "start": "14:00", "end": "15:00" },
        { "start": "15:30", "end": "16:30" },
        { "start": "17:00", "end": "18:00" }
      ],
      "recurrence": "weekly",
      "exceptions": []
    }
  }
}
```

#### Exemple d'un événement

```json
{
  "authorId": "assoc123",
  "type": "event",
  "title": "Nettoyage de printemps au Parc de la Rhônelle",
  "description": "Rejoignez-nous pour une journée de nettoyage et de sensibilisation à l'environnement au Parc de la Rhônelle. Matériel fourni, prévoir des vêtements adaptés.",
  "media": [
    { "type": "image", "url": "https://storage.example.com/events/nettoyage_parc.jpg" }
  ],
  "createdAt": "2024-10-05T09:10:00Z",
  "updatedAt": "2024-10-05T09:10:00Z",
  "location": {
    "address": "Parc de la Rhônelle, Entrée principale, 59300 Valenciennes",
    "coordinates": {
      "latitude": 50.3587,
      "longitude": 3.5194
    }
  },
  "visibility": "public",
  "tags": ["environnement", "nettoyage", "bénévolat", "nature", "parc"],
  "likeCount": 45,
  "commentCount": 12,
  "shareCount": 15,
  "authorName": "Les Amis de la Nature",
  "authorLogo": "https://storage.example.com/logos/amis_nature.png",
  "displayStatus": "upcoming",
  "validity": {
    "startDate": "2025-04-22T10:00:00Z",
    "endDate": "2025-04-22T16:00:00Z",
    "isRecurring": false
  },
  "eventDetails": {
    "category": "Environnement",
    "subCategory": "Action collective",
    "eventProgram": "10h00: Accueil des participants\n10h30: Distribution du matériel et briefing\n11h00-13h00: Nettoyage collectif\n13h00-14h00: Pause déjeuner (pique-nique partagé)\n14h00-15h30: Continuation du nettoyage\n15h30-16h00: Bilan et clôture",
    "frequency": "annuel",
    "startDate": "2025-04-22T10:00:00Z",
    "endDate": "2025-04-22T16:00:00Z",
    "location": "Parc de la Rhônelle, Entrée principale, 59300 Valenciennes",
    "locationType": "extérieur",
    "organizer": "Les Amis de la Nature - Valenciennes",
    "accessType": "free",
    "pricing": {
      "type": "free",
      "amount": 0
    },
    "capacity": 50,
    "prmAccessible": true,
    "minAge": 12,
    "requiredItems": "Vêtements adaptés à la météo, chaussures fermées, gants (si possible)",
    "websiteUrl": "https://amisdelanature.org/events/nettoyage-printemps-2025",
    "performers": []
  }
}
```

#### Exemple d'une promotion

```json
{
  "authorId": "business456",
  "type": "promo",
  "title": "2 croissants achetés, 1 offert",
  "description": "Pour bien commencer la semaine, profitez de notre offre spéciale sur les croissants au beurre : 2 achetés, 1 offert, tous les lundis !",
  "media": [
    { "type": "image", "url": "https://storage.example.com/promo/croissants_promo.jpg" }
  ],
  "createdAt": "2024-10-07T07:30:00Z",
  "updatedAt": "2024-10-07T07:30:00Z",
  "location": {
    "address": "22 Rue du Commerce, 59300 Valenciennes",
    "coordinates": {
      "latitude": 50.3562,
      "longitude": 3.5239
    }
  },
  "visibility": "public",
  "tags": ["boulangerie", "croissants", "promotion", "offre", "lundi"],
  "likeCount": 31,
  "commentCount": 4,
  "shareCount": 7,
  "authorName": "Boulangerie Martin",
  "authorLogo": "https://storage.example.com/logos/boulangerie_martin.png",
  "displayStatus": "active",
  "validity": {
    "startDate": "2024-10-07T07:00:00Z",
    "endDate": "2024-12-30T19:00:00Z",
    "isRecurring": true,
    "recurringPattern": {
      "daysOfWeek": [1],
      "timeRanges": [
        { "start": "07:00", "end": "19:00" }
      ]
    }
  },
  "promotionDetails": {
    "targetContentIds": ["product456"], // ID du produit "Croissant au beurre"
    "discountType": "buy_x_get_y",
    "discountValue": 100, // Pourcentage de réduction sur le produit offert
    "originalPrice": 3.60, // Prix de 3 croissants
    "discountedPrice": 2.40, // Prix de 2 croissants
    "validDays": [1], // Lundi uniquement
    "validTimes": ["morning", "afternoon"],
    "stockLimit": 100
  }
}
```

#### Exemple d'un troc/échange

```json
{
  "authorId": "user123",
  "type": "exchange",
  "title": "Échange PlayStation 4 contre Nintendo Switch",
  "description": "Je propose ma PlayStation 4 en très bon état avec 2 manettes et 5 jeux (détails dans l'annonce) contre une Nintendo Switch avec au moins 1 jeu.",
  "media": [
    { "type": "image", "url": "https://storage.example.com/exchange/ps4_1.jpg" },
    { "type": "image", "url": "https://storage.example.com/exchange/ps4_2.jpg" },
    { "type": "image", "url": "https://storage.example.com/exchange/games.jpg" }
  ],
  "createdAt": "2024-10-10T18:45:00Z",
  "updatedAt": "2024-10-10T18:45:00Z",
  "location": {
    "address": "Valenciennes, 59300",
    "coordinates": {
      "latitude": 50.3571,
      "longitude": 3.5183
    }
  },
  "visibility": "public",
  "tags": ["jeux vidéo", "console", "PlayStation", "Nintendo", "échange", "troc"],
  "likeCount": 8,
  "commentCount": 3,
  "shareCount": 1,
  "authorName": "Marie Dupont",
  "authorLogo": "https://storage.example.com/profiles/marie_dupont.jpg",
  "displayStatus": "active",
  "exchangeDetails": {
    "objectState": "veryGood",
    "brand": "Sony",
    "model": "PlayStation 4 Slim 1TB",
    "dimensions": { "height": 39, "length": 26, "width": 5.5 },
    "weight": 2.1,
    "accessories": ["2 manettes sans fil", "câble HDMI", "câble d'alimentation", "5 jeux (GTA V, FIFA 23, Spider-Man, Uncharted 4, God of War)"],
    "hasWarranty": false,
    "isWorking": true,
    "estimatedValue": 200,
    "desiredExchange": {
      "type": "object",
      "description": "Nintendo Switch avec au moins 1 jeu"
    },
    "exchangeLocation": "À définir ensemble sur Valenciennes",
    "preferredCommunication": "app"
  }
}
```

#### Exemple d'un deal express

```json
{
  "authorId": "business456",
  "type": "deal",
  "title": "Panier surprise de fin de journée - Boulangerie Martin",
  "description": "Panier surprise contenant une sélection variée de nos invendus du jour (pain, viennoiseries, pâtisseries) à prix réduit. Composition variable selon les disponibilités du jour.",
  "media": [
    { "type": "image", "url": "https://storage.example.com/deals/panier_surprise_boulangerie.jpg" }
  ],
  "createdAt": "2024-10-16T10:00:00Z",
  "updatedAt": "2024-10-16T10:00:00Z",
  "location": {
    "address": "22 Rue du Commerce, 59300 Valenciennes",
    "coordinates": {
      "latitude": 50.3562,
      "longitude": 3.5239
    }
  },
  "visibility": "public",
  "tags": ["antigaspi", "boulangerie", "panier", "réduction", "pain"],
  "likeCount": 15,
  "commentCount": 2,
  "shareCount": 4,
  "authorName": "Boulangerie Martin",
  "authorLogo": "https://storage.example.com/logos/boulangerie_martin.png",
  "displayStatus": "active",
  "validity": {
    "startDate": "2024-10-16T10:00:00Z",
    "endDate": "2024-10-16T19:00:00Z",
    "isRecurring": false
  },
  "dealDetails": {
    "basketType": "Panier anti-gaspi",
    "basketSubType": "Boulangerie",
    "basketContents": "Panier surprise contenant environ : 1 baguette, 2 pains spéciaux, 3 viennoiseries, 2 pâtisseries individuelles",
    "specialPrice": 8.50,
    "vatRate": 5.5,
    "regularValue": 20.00,
    "discountPercentage": 57.5,
    "pickupLocation": "22 Rue du Commerce, 59300 Valenciennes",
    "availableBaskets": 5,
    "additionalInfo": "Produits du jour, à consommer rapidement. Peut contenir des allergènes.",
    "pickupSlots": [
      { "date": "2024-10-16", "startTime": "18:30", "endTime": "19:00" }
    ]
  }
}
```

#### Exemple d'une offre d'emploi

```json
{
  "authorId": "business456",
  "type": "job",
  "title": "Boulanger(ère) H/F",
  "description": "La Boulangerie Martin recherche un/une boulanger(ère) pour rejoindre notre équipe. Vous participerez à la fabrication quotidienne des pains, viennoiseries et autres produits de boulangerie dans le respect de nos recettes et de nos valeurs artisanales.",
  "media": [
    { "type": "image", "url": "https://storage.example.com/jobs/boulanger_job.jpg" }
  ],
  "createdAt": "2024-09-30T14:20:00Z",
  "updatedAt": "2024-09-30T14:20:00Z",
  "location": {
    "address": "22 Rue du Commerce, 59300 Valenciennes",
    "coordinates": {
      "latitude": 50.3562,
      "longitude": 3.5239
    }
  },
  "visibility": "public",
  "tags": ["emploi", "boulangerie", "artisanat", "recrutement", "CDI"],
  "likeCount": 11,
  "commentCount": 3,
  "shareCount": 8,
  "authorName": "Boulangerie Martin",
  "authorLogo": "https://storage.example.com/logos/boulangerie_martin.png",
  "displayStatus": "active",
  "validity": {
    "startDate": "2024-09-30T14:20:00Z",
    "endDate": "2024-11-30T23:59:59Z",
    "isRecurring": false
  },
  "jobDetails": {
    "jobTitle": "Boulanger(ère)",
    "sector": "Alimentation",
    "positions": 1,
    "companyPresentation": "Boulangerie artisanale familiale depuis 1985, nous proposons des produits de qualité fabriqués sur place avec des matières premières sélectionnées.",
    "startDate": "2025-01-01T00:00:00Z",
    "contractType": "CDI",
    "employmentType": "temps plein",
    "workSchedule": "35h",
    "location": "Valenciennes",
    "workplaceType": "onSite",
    "weekendWork": true,
    "requiredExperience": "2 ans minimum",
    "requiredEducation": "CAP Boulangerie",
    "drivingLicense": "pas de permis requis",
    "skills": ["Fabrication de pain", "Viennoiseries", "Respect des normes d'hygiène", "Travail en équipe"],
    "salaryRange": { "min": 24000, "max": 28000 },
    "benefits": ["Tickets restaurant", "Mutuelle d'entreprise"],
    "applicationDeadline": "2024-11-30T23:59:59Z"
  }
}
```

#### Exemple d'un service de restauration à emporter

```json
{
  "authorId": "business789",
  "type": "foodService",
  "title": "Menu burger maison + frites + boisson",
  "description": "Notre menu best-seller : burger artisanal (steak haché français, cheddar affiné, sauce maison, légumes frais), accompagné de frites fraîches et d'une boisson au choix.",
  "media": [
    { "type": "image", "url": "https://storage.example.com/food/burger_menu.jpg" }
  ],
  "createdAt": "2024-10-15T11:30:00Z",
  "updatedAt": "2024-10-15T11:30:00Z",
  "location": {
    "address": "45 Rue de la Gastronomie, 59300 Valenciennes",
    "coordinates": {
      "latitude": 50.3575,
      "longitude": 3.5230
    }
  },
  "visibility": "public",
  "tags": ["burger", "frites", "à emporter", "fait maison", "rapide"],
  "likeCount": 42,
  "commentCount": 7,
  "shareCount": 9,
  "authorName": "Burger Corner",
  "authorLogo": "https://storage.example.com/logos/burger_corner.png",
  "displayStatus": "active",
  "foodServiceDetails": {
    "category": "Restauration",
    "subCategory": "Burger",
    "price": 12.90,
    "vatRate": 10,
    "ingredients": ["Pain artisanal", "Steak haché 150g", "Cheddar", "Tomate", "Salade", "Oignon", "Sauce maison", "Pommes de terre fraîches"],
    "allergens": ["Gluten", "Lactose", "Œuf", "Moutarde"],
    "origin": { 
      "viande": "France", 
      "légumes": "Production locale", 
      "pain": "Boulangerie partenaire locale" 
    },
    "weight": 400,
    "isHomemade": true,
    "dietaryType": [],
    "extras": [
      { "name": "Double steak", "price": 3.50 },
      { "name": "Supplément fromage", "price": 1.00 },
      { "name": "Bacon", "price": 1.50 }
    ],
    "pickupType": "scheduled",
    "availableDays": [1, 2, 3, 4, 5, 6],
    "availableTimeSlots": [
      { "start": "11:30", "end": "14:00" },
      { "start": "18:30", "end": "22:00" }
    ],
    "minPreparationTime": 15,
    "maxDailyAvailability": 50,
    "pickupLocation": "45 Rue de la Gastronomie, 59300 Valenciennes",
    "pickupInstructions": "Présentez-vous au comptoir et donnez votre nom"
  }
}
```

---

## Collection Subscriptions

Gère les relations d'abonnement entre les utilisateurs.

### Structure

```
subscriptions/
  ├─ {subscriptionId}/
     ├─ followerId: string (userId)
     ├─ followedId: string (userId)
     ├─ createdAt: timestamp
     ├─ notificationsEnabled: boolean
```

### Exemple

```json
{
  "followerId": "user123",
  "followedId": "business456",
  "createdAt": "2024-10-05T09:30:00Z",
  "notificationsEnabled": true
}
```

---

## Collection Interactions

Stocke les interactions des utilisateurs avec le contenu (likes, commentaires, partages).

### Structure

```
interactions/
  ├─ {interactionId}/
     ├─ contentId: string
     ├─ userId: string
     ├─ type: "like" | "comment" | "share"
     ├─ createdAt: timestamp
     ├─ text: string // Pour les commentaires
     ├─ parentId: string // Pour les réponses aux commentaires
```

### Exemples

#### Exemple d'un like

```json
{
  "contentId": "post789",
  "userId": "user123",
  "type": "like",
  "createdAt": "2024-10-16T18:22:00Z"
}
```

#### Exemple d'un commentaire

```json
{
  "contentId": "post789",
  "userId": "user123",
  "type": "comment",
  "createdAt": "2024-10-16T18:25:00Z",
  "text": "Superbe photo ! J'adore cet endroit, c'est vraiment relaxant."
}
```

#### Exemple d'une réponse à un commentaire

```json
{
  "contentId": "post789",
  "userId": "user456",
  "type": "comment",
  "createdAt": "2024-10-16T18:30:00Z",
  "text": "Oui, c'est mon coin préféré du parc !",
  "parentId": "comment123" // ID du commentaire parent
}
```

#### Exemple d'un partage

```json
{
  "contentId": "post789",
  "userId": "user123",
  "type": "share",
  "createdAt": "2024-10-16T18:35:00Z"
}
```

---

## Collection Slots

Gère les créneaux horaires disponibles pour les services.

### Structure

```
slots/
  ├─ {slotId}/
     ├─ providerId: string (userId)
     ├─ serviceId: string (contentId)
     ├─ date: timestamp
     ├─ startTime: timestamp
     ├─ endTime: timestamp
     ├─ status: "available" | "booked" | "blocked" | "cancelled"
     ├─ capacity: number // Pour les services de groupe
     ├─ bookedCount: number // Nombre actuel de réservations
     ├─ transactions: [string] // Références aux transactions qui utilisent ce créneau
     ├─ location: {
        ├─ address: string
        ├─ coordinates: { latitude, longitude }
        ├─ type: "provider_location" | "customer_location" | "online"
     }
```

### Exemple

```json
{
  "providerId": "business789",
  "serviceId": "service123",
  "date": "2024-11-15T00:00:00Z",
  "startTime": "2024-11-15T14:00:00Z",
  "endTime": "2024-11-15T15:00:00Z",
  "status": "available",
  "capacity": 1,
  "bookedCount": 0,
  "transactions": [],
  "location": {
    "address": "8 Avenue du Bien-être, 59300 Valenciennes",
    "coordinates": {
      "latitude": 50.3598,
      "longitude": 3.5215
    },
    "type": "provider_location"
  }
}
```

---

## Collection AvailabilityPatterns

Définit les modèles de disponibilité récurrents pour générer automatiquement des créneaux.

### Structure

```
availabilityPatterns/
  ├─ {patternId}/
     ├─ providerId: string (userId)
     ├─ serviceId: string (contentId) // optionnel, si spécifique à un service
     ├─ daysOfWeek: [0-6] // 0=dimanche
     ├─ timeSlots: [{
        ├─ startTime: string ("HH:MM")
        ├─ endTime: string ("HH:MM")
        ├─ duration: number (minutes) // Pour les rdv
        ├─ capacity: number // Pour les services de groupe
     }]
     ├─ location: string // Lieu où le service est fourni
     ├─ recurrence: "weekly" | "biweekly" | "monthly"
     ├─ startDate: timestamp // Date de début de validité du pattern
     ├─ endDate: timestamp // Date de fin de validité du pattern
     ├─ active: boolean
```

### Exemple

```json
{
  "providerId": "business789",
  "serviceId": "service123",
  "daysOfWeek": [1, 2, 3, 4, 5],
  "timeSlots": [
    {
      "startTime": "10:00",
      "endTime": "11:00",
      "duration": 60,
      "capacity": 1
    },
    {
      "startTime": "11:30",
      "endTime": "12:30",
      "duration": 60,
      "capacity": 1
    },
    {
      "startTime": "14:00",
      "endTime": "15:00",
      "duration": 60,
      "capacity": 1
    },
    {
      "startTime": "15:30",
      "endTime": "16:30",
      "duration": 60,
      "capacity": 1
    },
    {
      "startTime": "17:00",
      "endTime": "18:00",
      "duration": 60,
      "capacity": 1
    }
  ],
  "location": {
    "address": "8 Avenue du Bien-être, 59300 Valenciennes",
    "coordinates": {
      "latitude": 50.3598,
      "longitude": 3.5215
    },
    "type": "provider_location"
  },
  "recurrence": "weekly",
  "startDate": "2024-10-01T00:00:00Z",
  "endDate": "2024-12-31T23:59:59Z",
  "active": true
}
```

---

## Collection Transactions

Gère toutes les transactions commerciales (commandes, réservations, etc.).

### Structure

```
transactions/
  ├─ {transactionId}/
     ├─ type: "product_order" | "service_booking" | "express_deal" | "appointment" | "event_reservation"
     ├─ customerId: string (userId)
     ├─ providerId: string (userId)
     ├─ createdAt: timestamp
     ├─ updatedAt: timestamp
     ├─ status: "pending" | "confirmed" | "paid" | "preparing" | "ready" | "completed" | "cancelled"
     ├─ totalAmount: number
     ├─ items: [{ // Pour les commandes de produits ou deals
        ├─ contentId: string
        ├─ quantity: number
        ├─ unitPrice: number
        ├─ options: { ... } // Variantes, suppléments, etc.
     }]
     ├─ appliedPromotions: [{
        ├─ promotionId: string
        ├─ code: string
        ├─ discountType: string
        ├─ discountValue: number
        ├─ amountSaved: number
     }]
     ├─ discountTotal: number
     ├─ paymentDetails: {
        ├─ paymentMethod: "stripe" | "onsite" | "free"
        ├─ stripePaymentId: string
        ├─ isPaid: boolean
        ├─ receiptUrl: string
     }
     ├─ pickupDetails: { // Pour les commandes à emporter
        ├─ location: string
        ├─ date: timestamp
        ├─ timeSlot: string
        ├─ instructions: string
     }
     ├─ bookingDetails: { // Pour les services et RDV
        ├─ serviceId: string
        ├─ slotId: string  
        ├─ date: timestamp
        ├─ startTime: timestamp
        ├─ endTime: timestamp
        ├─ location: string
        ├─ locationType: "provider_location" | "customer_location" | "online"
        ├─ notes: string // Demandes spéciales
        ├─ participants: number
     }
     ├─ cancellationDetails: {
        ├─ cancelledAt: timestamp
        ├─ cancelledBy: string (userId)
        ├─ reason: string
        ├─ refundAmount: number
     }
```

### Exemples

#### Exemple d'une commande de produit

```json
{
  "type": "product_order",
  "customerId": "user123",
  "providerId": "business456",
  "createdAt": "2024-10-16T09:45:00Z",
  "updatedAt": "2024-10-16T09:45:00Z",
  "status": "confirmed",
  "totalAmount": 7.20,
  "items": [
    {
      "contentId": "product001", // Baguette tradition
      "quantity": 2,
      "unitPrice": 1.20,
      "options": {}
    },
    {
      "contentId": "product002", // Pain aux céréales
      "quantity": 1,
      "unitPrice": 2.40,
      "options": {}
    },
    {
      "contentId": "product003", // Pain au chocolat
      "quantity": 3,
      "unitPrice": 1.10,
      "options": {}
    }
  ],
  "appliedPromotions": [],
  "discountTotal": 0,
  "paymentDetails": {
    "paymentMethod": "onsite",
    "isPaid": false
  },
  "pickupDetails": {
    "location": "22 Rue du Commerce, 59300 Valenciennes",
    "date": "2024-10-16T00:00:00Z",
    "timeSlot": "17:00-18:00",
    "instructions": ""
  }
}
```

#### Exemple d'une réservation de service

```json
{
  "type": "service_booking",
  "customerId": "user123",
  "providerId": "business789",
  "createdAt": "2024-10-16T10:15:00Z",
  "updatedAt": "2024-10-16T10:15:00Z",
  "status": "confirmed",
  "totalAmount": 65.00,
  "appliedPromotions": [],
  "discountTotal": 0,
  "paymentDetails": {
    "paymentMethod": "stripe",
    "stripePaymentId": "pi_3O6KjdCFhQ0XhkZ61LDyZrqT",
    "isPaid": true,
    "receiptUrl": "https://pay.stripe.com/receipts/..."
  },
  "bookingDetails": {
    "serviceId": "service123",
    "slotId": "slot456",
    "date": "2024-11-15T00:00:00Z",
    "startTime": "2024-11-15T14:00:00Z",
    "endTime": "2024-11-15T15:00:00Z",
    "location": "8 Avenue du Bien-être, 59300 Valenciennes",
    "locationType": "provider_location",
    "notes": "Première séance de massage, tensions dans le dos",
    "participants": 1
  }
}
```

#### Exemple d'une commande de deal express

```json
{
  "type": "express_deal",
  "customerId": "user456",
  "providerId": "business456",
  "createdAt": "2024-10-16T11:30:00Z",
  "updatedAt": "2024-10-16T11:30:00Z",
  "status": "confirmed",
  "totalAmount": 8.50,
  "items": [
    {
      "contentId": "deal001", // Panier surprise
      "quantity": 1,
      "unitPrice": 8.50,
      "options": {}
    }
  ],
  "appliedPromotions": [],
  "discountTotal": 0,
  "paymentDetails": {
    "paymentMethod": "stripe",
    "stripePaymentId": "pi_3O6LmqCFhQ0XhkZ61U7yMpVw",
    "isPaid": true,
    "receiptUrl": "https://pay.stripe.com/receipts/..."
  },
  "pickupDetails": {
    "location": "22 Rue du Commerce, 59300 Valenciennes",
    "date": "2024-10-16T00:00:00Z",
    "timeSlot": "18:30-19:00",
    "instructions": ""
  }
}
```

#### Exemple d'un rendez-vous gratuit

```json
{
  "type": "appointment",
  "customerId": "user789",
  "providerId": "business101",
  "createdAt": "2024-10-16T14:20:00Z",
  "updatedAt": "2024-10-16T14:20:00Z",
  "status": "confirmed",
  "totalAmount": 0,
  "paymentDetails": {
    "paymentMethod": "free",
    "isPaid": true
  },
  "bookingDetails": {
    "serviceId": "service789",
    "slotId": "slot123",
    "date": "2024-10-20T00:00:00Z",
    "startTime": "2024-10-20T11:00:00Z",
    "endTime": "2024-10-20T11:30:00Z",
    "location": "En ligne via visioconférence",
    "locationType": "online",
    "notes": "Premier contact pour discuter du projet de rénovation",
    "participants": 1
  }
}
```

---

## Collection Promotions

Gère les promotions et codes promo.

### Structure

```
promotions/
  ├─ {promotionId}/
     ├─ type: "automatic" | "code" | "loyalty" | "first_purchase"
     ├─ creatorId: string (ID du commerçant qui a créé la promo)
     ├─ title: string
     ├─ description: string
     ├─ active: boolean
     ├─ createdAt: timestamp
     ├─ validFrom: timestamp
     ├─ validUntil: timestamp
     ├─ discountType: "percentage" | "fixed_amount" | "free_shipping" | "buy_x_get_y"
     ├─ discountValue: number
     ├─ code: string (vide pour les promotions automatiques)
     ├─ usageLimit: {
        ├─ totalLimit: number (nombre total d'utilisations possibles)
        ├─ perUserLimit: number (nombre d'utilisations possibles par utilisateur)
        ├─ currentUses: number (compteur d'utilisations)
     }
     ├─ conditions: {
        ├─ minimumPurchase: number (montant minimum du panier)
        ├─ applicableProducts: [string] (IDs des produits concernés)
        ├─ applicableCategories: [string] (catégories concernées)
        ├─ applicableServices: [string] (IDs des services concernés)
        ├─ userType: "all" | "new" | "returning"
        ├─ validDays: [0-6] (jours de la semaine où la promo est valide)
        ├─ validHours: { start: "HH:MM", end: "HH:MM" }
        ├─ locationRestriction: boolean
        ├─ radius: number (rayon en km si restriction géographique)
        ├─ coordinates: { latitude, longitude } (centre du rayon)
     }
     ├─ exclusions: {
        ├─ excludedProducts: [string]
        ├─ excludedCategories: [string]
        ├─ excludedUsers: [string]
        ├─ cannotCombineWith: [string] (autres codes promo non combinables)
     }
     ├─ displayOptions: {
        ├─ showOnProductPage: boolean
        ├─ showInFeed: boolean
        ├─ highlightInProfile: boolean
        ├─ badgeColor: string (code couleur)
        ├─ displayPriority: number (ordre d'affichage)
     }
```

### Exemples

#### Exemple d'un code promo

```json
{
  "type": "code",
  "creatorId": "business789",
  "title": "Première séance à -20%",
  "description": "Bénéficiez de 20% de réduction sur votre première séance de massage",
  "active": true,
  "createdAt": "2024-10-01T09:00:00Z",
  "validFrom": "2024-10-01T00:00:00Z",
  "validUntil": "2024-12-31T23:59:59Z",
  "discountType": "percentage",
  "discountValue": 20,
  "code": "BIENVENUE20",
  "usageLimit": {
    "totalLimit": 100,
    "perUserLimit": 1,
    "currentUses": 12
  },
  "conditions": {
    "minimumPurchase": 0,
    "applicableServices": ["service123", "service456", "service789"],
    "userType": "new",
    "validDays": [1, 2, 3, 4, 5],
    "locationRestriction": false
  },
  "exclusions": {
    "cannotCombineWith": ["FIDELITE10"]
  },
  "displayOptions": {
    "showOnProductPage": true,
    "showInFeed": true,
    "highlightInProfile": true,
    "badgeColor": "#FF5722",
    "displayPriority": 1
  }
}
```

#### Exemple d'une promotion automatique

```json
{
  "type": "automatic",
  "creatorId": "business456",
  "title": "Happy Hour - 10% sur toutes les viennoiseries",
  "description": "10% de réduction sur toutes les viennoiseries entre 17h et 19h",
  "active": true,
  "createdAt": "2024-10-05T08:00:00Z",
  "validFrom": "2024-10-05T00:00:00Z",
  "validUntil": "2024-12-31T23:59:59Z",
  "discountType": "percentage",
  "discountValue": 10,
  "code": "",
  "usageLimit": {
    "totalLimit": 0,
    "perUserLimit": 0,
    "currentUses": 87
  },
  "conditions": {
    "minimumPurchase": 0,
    "applicableCategories": ["Viennoiseries"],
    "userType": "all",
    "validDays": [1, 2, 3, 4, 5],
    "validHours": { "start": "17:00", "end": "19:00" },
    "locationRestriction": false
  },
  "exclusions": {},
  "displayOptions": {
    "showOnProductPage": true,
    "showInFeed": false,
    "highlightInProfile": false,
    "badgeColor": "#4CAF50",
    "displayPriority": 2
  }
}
```

---

## Collection UserPromotions

Suit l'utilisation des promotions par utilisateur.

### Structure

```
userPromotions/
  ├─ {userPromotionId}/
     ├─ userId: string
     ├─ promotionId: string
     ├─ usedCount: number
     ├─ lastUsedAt: timestamp
     ├─ firstUsedAt: timestamp
     ├─ transactions: [string] (IDs des transactions où cette promo a été utilisée)
```

### Exemple

```json
{
  "userId": "user123",
  "promotionId": "promo456",
  "usedCount": 1,
  "lastUsedAt": "2024-10-16T10:15:00Z",
  "firstUsedAt": "2024-10-16T10:15:00Z",
  "transactions": ["trans789"]
}
```

---

## Collection Notifications

Gère les notifications envoyées aux utilisateurs.

### Structure

```
notifications/
  ├─ {notificationId}/
     ├─ userId: string (destinataire)
     ├─ type: "new_follower" | "like" | "comment" | "mention" | "promo" | "order_status" | "booking_reminder"
     ├─ createdAt: timestamp
     ├─ read: boolean
     ├─ title: string
     ├─ body: string
     ├─ imageUrl: string
     ├─ data: {
        ├─ sourceId: string // ID de l'élément source (contenu, utilisateur, etc.)
        ├─ sourceType: string // Type de l'élément source
        ├─ actionUserId: string // ID de l'utilisateur qui a déclenché la notification
     }
     ├─ sentToDevice: boolean
```

### Exemples

#### Exemple de notification d'abonnement

```json
{
  "userId": "user123",
  "type": "new_follower",
  "createdAt": "2024-10-16T15:30:00Z",
  "read": false,
  "title": "Nouvel abonné",
  "body": "Boulangerie Martin s'est abonné à votre profil",
  "imageUrl": "https://storage.example.com/logos/boulangerie_martin.png",
  "data": {
    "sourceId": "business456",
    "sourceType": "user",
    "actionUserId": "business456"
  },
  "sentToDevice": true
}
```

#### Exemple de notification de commande

```json
{
  "userId": "user123",
  "type": "order_status",
  "createdAt": "2024-10-16T17:15:00Z",
  "read": false,
  "title": "Commande prête",
  "body": "Votre commande chez Boulangerie Martin est prête à être récupérée",
  "imageUrl": "https://storage.example.com/logos/boulangerie_martin.png",
  "data": {
    "sourceId": "trans456",
    "sourceType": "transaction",
    "actionUserId": "business456"
  },
  "sentToDevice": true
}
```

#### Exemple de notification de promotion

```json
{
  "userId": "user123",
  "type": "promo",
  "createdAt": "2024-10-16T08:00:00Z",
  "read": false,
  "title": "Promotion du jour",
  "body": "2 croissants achetés, 1 offert aujourd'hui chez Boulangerie Martin",
  "imageUrl": "https://storage.example.com/promo/croissants_promo.jpg",
  "data": {
    "sourceId": "promo789",
    "sourceType": "content",
    "actionUserId": "business456"
  },
  "sentToDevice": true
}
```

---

## Implémentation et Utilisation

### Requête typique pour le fil d'actualité

```dart
Future<List<Content>> getFeedContent({
  String? lastContentId,
  int limit = 20,
  List<String> contentTypes = const [],
  bool activeOnly = true,
}) async {
  final currentUser = _auth.currentUser;
  if (currentUser == null) return [];
  
  // Récupérer les abonnements de l'utilisateur
  final subscriptionsSnapshot = await _firestore
      .collection('subscriptions')
      .where('followerId', isEqualTo: currentUser.uid)
      .get();
  
  List<String> followedIds = subscriptionsSnapshot.docs
      .map((doc) => doc.data()['followedId'] as String)
      .toList();
  
  // Construire la requête
  Query query = _firestore.collection('content')
      .where('authorId', whereIn: followedIds)
      .where('visibility', isEqualTo: 'public');
  
  // Filtrer par types de contenu si spécifié
  if (contentTypes.isNotEmpty) {
    query = query.where('type', whereIn: contentTypes);
  }
  
  // Filtrer pour n'afficher que les contenus actifs
  if (activeOnly) {
    query = query.where('displayStatus', isEqualTo: 'active');
  }
  
  // Trier par date de création (les plus récents d'abord)
  query = query.orderBy('createdAt', descending: true).limit(limit);
  
  // Ajouter le curseur pour la pagination
  if (lastContentId != null) {
    final lastDoc = await _firestore.collection('content').doc(lastContentId).get();
    query = query.startAfterDocument(lastDoc);
  }
  
  // Exécuter la requête
  final snapshot = await query.get();
  
  // Convertir les documents en objets Content
  return snapshot.docs.map((doc) {
    return Content.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
  }).toList();
}
```

### Requête pour trouver des services ou professionnels à proximité

```dart
Future<List<Content>> getNearbyServices({
  required double latitude,
  required double longitude,
  double radiusInKm = 10,
  String? category,
  List<String> serviceTypes = const [],
}) async {
  // Utiliser GeoFirestore pour la requête géospatiale
  final GeoFirestore geoFirestore = GeoFirestore(_firestore.collection('content'));
  
  // Centre de la recherche
  final center = GeoPoint(latitude, longitude);
  
  // Requête de base
  GeoFirestoreQuery query = geoFirestore.queryAtLocation(center, radiusInKm);
  
  // Filtres additionnels
  if (serviceTypes.isNotEmpty) {
    query = query.queryBuilder()
      .where('type', whereIn: serviceTypes)
      .where('visibility', isEqualTo: 'public')
      .where('displayStatus', isEqualTo: 'active');
  }
  
  if (category != null) {
    query = query.queryBuilder()
      .where('serviceDetails.category', isEqualTo: category);
  }
  
  // Exécuter la requête
  final documents = await query.get();
  
  // Convertir les documents en objets Content
  return documents.map((doc) {
    return Content.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
  }).toList();
}
```

### Réservation d'un créneau pour un service

```dart
Future<String> bookServiceSlot({
  required String serviceId,
  required String slotId,
  required double amount,
  String? notes,
  int participants = 1,
}) async {
  final currentUser = _auth.currentUser;
  if (currentUser == null) throw Exception("Non connecté");
  
  // Récupérer les informations du service
  final serviceDoc = await _firestore.collection('content').doc(serviceId).get();
  if (!serviceDoc.exists) throw Exception("Service non trouvé");
  
  final serviceData = serviceDoc.data()!;
  final providerId = serviceData['authorId'];
  
  // Récupérer les informations du créneau
  final slotDoc = await _firestore.collection('slots').doc(slotId).get();
  if (!slotDoc.exists) throw Exception("Créneau non trouvé");
  
  final slotData = slotDoc.data()!;
  
  // Vérifier la disponibilité du créneau
  if (slotData['status'] != 'available') 
    throw Exception("Ce créneau n'est plus disponible");
  
  if (slotData['bookedCount'] >= slotData['capacity'])
    throw Exception("Ce créneau est complet");
  
  // Créer la transaction dans un batch
  final batch = _firestore.batch();
  
  final transactionRef = _firestore.collection('transactions').doc();
  
  final paymentMethod = amount > 0 ? "stripe" : "free";
  
  batch.set(transactionRef, {
    'type': 'service_booking',
    'customerId': currentUser.uid,
    'providerId': providerId,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'status': paymentMethod == 'free' ? 'confirmed' : 'pending',
    'totalAmount': amount,
    'paymentDetails': {
      'paymentMethod': paymentMethod,
      'isPaid': paymentMethod == 'free',
    },
    'bookingDetails': {
      'serviceId': serviceId,
      'slotId': slotId,
      'date': slotData['date'],
      'startTime': slotData['startTime'],
      'endTime': slotData['endTime'],
      'location': slotData['location']['address'],
      'locationType': slotData['location']['type'],
      'notes': notes ?? '',
      'participants': participants,
    }
  });
  
  // Mettre à jour le statut du créneau
  batch.update(_firestore.collection('slots').doc(slotId), {
    'status': slotData['capacity'] > 1 && (slotData['bookedCount'] + 1) < slotData['capacity'] 
        ? 'available' 
        : 'booked',
    'bookedCount': FieldValue.increment(1),
    'transactions': FieldValue.arrayUnion([transactionRef.id])
  });
  
  // Exécuter le batch
  await batch.commit();
  
  // Créer une notification pour le fournisseur de service
  await _firestore.collection('notifications').add({
    'userId': providerId,
    'type': 'booking',
    'createdAt': FieldValue.serverTimestamp(),
    'read': false,
    'title': 'Nouvelle réservation',
    'body': 'Vous avez une nouvelle réservation pour le ${DateFormat('dd/MM/yyyy à HH:mm').format(slotData['startTime'].toDate())}',
    'data': {
      'sourceId': transactionRef.id,
      'sourceType': 'transaction',
      'actionUserId': currentUser.uid
    },
    'sentToDevice': false
  });
  
  return transactionRef.id;
}
```

### Commande d'un produit

```dart
Future<String> orderProducts({
  required List<CartItem> items,
  required String pickupTimeSlot,
  String? instructions,
  String? promoCode,
}) async {
  final currentUser = _auth.currentUser;
  if (currentUser == null) throw Exception("Non connecté");
  
  // Vérifier la disponibilité et récupérer les infos produits
  final productIds = items.map((item) => item.productId).toList();
  
  final productsSnapshot = await _firestore
      .collection('content')
      .where(FieldPath.documentId, whereIn: productIds)
      .get();
  
  final products = productsSnapshot.docs.map((doc) {
    return {
      'id': doc.id,
      'data': doc.data(),
    };
  }).toList();
  
  // Vérifier que tous les produits existent
  if (products.length != productIds.length)
    throw Exception("Certains produits ne sont plus disponibles");
  
  // Vérifier la disponibilité des quantités
  for (final item in items) {
    final product = products.firstWhere((p) => p['id'] == item.productId);
    final availability = product['data']['productDetails']['availability'] ?? 0;
    
    if (item.quantity > availability)
      throw Exception("Quantité non disponible pour ${product['data']['title']}");
  }
  
  // Calculer le total
  double totalAmount = 0;
  
  final orderItems = items.map((item) {
    final product = products.firstWhere((p) => p['id'] == item.productId);
    final price = product['data']['productDetails']['price'];
    
    totalAmount += price * item.quantity;
    
    return {
      'contentId': item.productId,
      'quantity': item.quantity,
      'unitPrice': price,
      'options': item.options
    };
  }).toList();
  
  // Déterminer le vendeur (tous les produits doivent être du même vendeur)
  final providerId = products.first['data']['authorId'];
  
  // Appliquer un code promo si fourni
  double discountTotal = 0;
  List<Map<String, dynamic>> appliedPromotions = [];
  
  if (promoCode != null && promoCode.isNotEmpty) {
    final promoResult = await _applyPromoCode(promoCode, items, totalAmount);
    
    if (promoResult['valid']) {
      discountTotal = promoResult['discountAmount'];
      appliedPromotions.add(promoResult['promotion']);
    }
  }
  
  // Créer la transaction
  final transactionRef = await _firestore.collection('transactions').add({
    'type': 'product_order',
    'customerId': currentUser.uid,
    'providerId': providerId,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'status': 'pending',
    'totalAmount': totalAmount - discountTotal,
    'items': orderItems,
    'appliedPromotions': appliedPromotions,
    'discountTotal': discountTotal,
    'paymentDetails': {
      'paymentMethod': 'stripe',
      'isPaid': false
    },
    'pickupDetails': {
      'location': products.first['data']['location']['address'],
      'date': FieldValue.serverTimestamp(),
      'timeSlot': pickupTimeSlot,
      'instructions': instructions ?? ''
    }
  });
  
  // Mettre à jour le stock des produits
  final batch = _firestore.batch();
  
  for (final item in items) {
    final productRef = _firestore.collection('content').doc(item.productId);
    batch.update(productRef, {
      'productDetails.availability': FieldValue.increment(-item.quantity)
    });
  }
  
  await batch.commit();
  
  // Créer une notification pour le vendeur
  await _firestore.collection('notifications').add({
    'userId': providerId,
    'type': 'order',
    'createdAt': FieldValue.serverTimestamp(),
    'read': false,
    'title': 'Nouvelle commande',
    'body': 'Vous avez reçu une nouvelle commande',
    'data': {
      'sourceId': transactionRef.id,
      'sourceType': 'transaction',
      'actionUserId': currentUser.uid
    },
    'sentToDevice': false
  });
  
  return transactionRef.id;
}
```

### Application d'un code promo

```dart
Future<Map<String, dynamic>> _applyPromoCode(
  String code, 
  List<CartItem> items,
  double totalAmount
) async {
  final currentUser = _auth.currentUser;
  if (currentUser == null) 
    return {'valid': false, 'message': 'Non connecté'};
  
  // Rechercher le code promo
  final promoSnapshot = await _firestore
      .collection('promotions')
      .where('code', isEqualTo: code)
      .where('active', isEqualTo: true)
      .where('validFrom', isLessThanOrEqualTo: FieldValue.serverTimestamp())
      .where('validUntil', isGreaterThanOrEqualTo: FieldValue.serverTimestamp())
      .limit(1)
      .get();
  
  if (promoSnapshot.docs.isEmpty)
    return {'valid': false, 'message': 'Code promo invalide ou expiré'};
  
  final promotion = promoSnapshot.docs.first.data();
  final promotionId = promoSnapshot.docs.first.id;
  
  // Vérifier les limites d'utilisation
  if (promotion['usageLimit']['totalLimit'] > 0 && 
      promotion['usageLimit']['currentUses'] >= promotion['usageLimit']['totalLimit']) {
    return {'valid': false, 'message': 'Ce code promo a atteint son nombre maximum d\'utilisations'};
  }
  
  // Vérifier les limites par utilisateur
  if (promotion['usageLimit']['perUserLimit'] > 0) {
    final userPromoSnapshot = await _firestore
        .collection('userPromotions')
        .where('userId', isEqualTo: currentUser.uid)
        .where('promotionId', isEqualTo: promotionId)
        .limit(1)
        .get();
    
    if (!userPromoSnapshot.docs.isEmpty) {
      final userPromo = userPromoSnapshot.docs.first.data();
      if (userPromo['usedCount'] >= promotion['usageLimit']['perUserLimit']) {
        return {'valid': false, 'message': 'Vous avez déjà utilisé ce code promo le nombre maximum de fois'};
      }
    }
  }
  
  // Vérifier les conditions (jour de la semaine)
  final today = DateTime.now().weekday % 7; // 0-6 où 0 = dimanche
  
  if (promotion['conditions']['validDays'] != null && 
      promotion['conditions']['validDays'].isNotEmpty && 
      !promotion['conditions']['validDays'].contains(today)) {
    return {'valid': false, 'message': 'Ce code promo n\'est pas valable aujourd\'hui'};
  }
  
  // Vérifier le montant minimum d'achat
  if (promotion['conditions']['minimumPurchase'] != null && 
      totalAmount < promotion['conditions']['minimumPurchase']) {
    return {
      'valid': false, 
      'message': 'Ce code promo nécessite un achat minimum de ${promotion['conditions']['minimumPurchase']}€'
    };
  }
  
  // Vérifier si les produits sont éligibles
  if (promotion['conditions']['applicableProducts'] != null && 
      promotion['conditions']['applicableProducts'].isNotEmpty) {
    
    final applicableProducts = promotion['conditions']['applicableProducts'];
    final hasEligibleProduct = items.any((item) => applicableProducts.contains(item.productId));
    
    if (!hasEligibleProduct) {
      return {'valid': false, 'message': 'Ce code promo n\'est pas applicable aux produits de votre panier'};
    }
  }
  
  // Calculer la remise
  double discountAmount = 0;
  
  switch (promotion['discountType']) {
    case 'percentage':
      discountAmount = (totalAmount * promotion['discountValue']) / 100;
      break;
    
    case 'fixed_amount':
      discountAmount = math.min(promotion['discountValue'], totalAmount);
      break;
    
    case 'free_shipping':
      // Logic for free shipping would be handled separately
      discountAmount = 0;
      break;
    
    case 'buy_x_get_y':
      // Complex logic for buy X get Y would be implemented here
      // ...
      break;
    
    default:
      discountAmount = 0;
  }
  
  return {
    'valid': true,
    'discountAmount': discountAmount,
    'promotion': {
      'promotionId': promotionId,
      'code': promotion['code'],
      'discountType': promotion['discountType'],
      'discountValue': promotion['discountValue'],
      'amountSaved': discountAmount
    }
  };
}
```

## Considérations de sécurité et d'optimisation

### Règles de sécurité Firestore

Voici un exemple de règles de sécurité pour cette structure:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Fonction pour vérifier si l'utilisateur est authentifié
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Fonction pour vérifier si l'utilisateur est le propriétaire du document
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    // Fonction pour vérifier si l'utilisateur est un professionnel
    function isProfessional() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.type == 'professional';
    }
    
    // Fonction pour vérifier si l'utilisateur est une association
    function isAssociation() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.type == 'association';
    }
    
    // Collection Users
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow create: if isOwner(userId);
      allow update: if isOwner(userId);
      allow delete: if false; // La suppression du compte doit se faire via une fonction Cloud
    }
    
    // Collection Content
    match /content/{contentId} {
      allow read: if isAuthenticated() && resource.data.visibility == 'public';
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() && isOwner(resource.data.authorId);
      allow delete: if isAuthenticated() && isOwner(resource.data.authorId);
    }
    
    // Collection Subscriptions
    match /subscriptions/{subscriptionId} {
      allow read: if isAuthenticated() && (
        isOwner(resource.data.followerId) || isOwner(resource.data.followedId)
      );
      allow create: if isAuthenticated() && isOwner(request.resource.data.followerId);
      allow delete: if isAuthenticated() && isOwner(resource.data.followerId);
    }
    
    // Collection Interactions
    match /interactions/{interactionId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && isOwner(request.resource.data.userId);
      allow update: if isAuthenticated() && isOwner(resource.data.userId);
      allow delete: if isAuthenticated() && isOwner(resource.data.userId);
    }
    
    // Collection Slots
    match /slots/{slotId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && (isProfessional() || isAssociation());
      allow update: if isAuthenticated() && (
        isOwner(resource.data.providerId) || 
        resource.data.transactions.hasAny([request.auth.uid])
      );
      allow delete: if isAuthenticated() && isOwner(resource.data.providerId);
    }
    
    // Collection AvailabilityPatterns
    match /availabilityPatterns/{patternId} {
      allow read: if isAuthenticated();
      allow write: if isAuthenticated() && isOwner(resource.data.providerId);
    }
    
    // Collection Transactions
    match /transactions/{transactionId} {
      allow read: if isAuthenticated() && (
        isOwner(resource.data.customerId) || isOwner(resource.data.providerId)
      );
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() && (
        isOwner(resource.data.customerId) || isOwner(resource.data.providerId)
      );
      allow delete: if false; // Les transactions ne doivent jamais être supprimées
    }
    
    // Collection Promotions
    match /promotions/{promotionId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() && (isProfessional() || isAssociation());
      allow update: if isAuthenticated() && isOwner(resource.data.creatorId);
      allow delete: if isAuthenticated() && isOwner(resource.data.creatorId);
    }
    
    // Collection UserPromotions
    match /userPromotions/{userPromotionId} {
      allow read: if isAuthenticated() && isOwner(resource.data.userId);
      // Les écritures sont gérées par des fonctions Cloud
      allow write: if false;
    }
    
    // Collection Notifications
    match /notifications/{notificationId} {
      allow read: if isAuthenticated() && isOwner(resource.data.userId);
      allow update: if isAuthenticated() && isOwner(resource.data.userId);
      // Les créations sont gérées par des fonctions Cloud
      allow create, delete: if false;
    }
  }
}
```

### Index Firestore recommandés

Pour optimiser les performances des requêtes, voici les index recommandés:

1. Collection `content`:
   - Composé: `authorId` (ASC), `createdAt` (DESC)
   - Composé: `type` (ASC), `createdAt` (DESC)
   - Composé: `type` (ASC), `displayStatus` (ASC), `createdAt` (DESC)
   - Composé: `validity.recurringPattern.daysOfWeek` (ARRAY), `displayStatus` (ASC)

2. Collection `subscriptions`:
   - Composé: `followerId` (ASC), `createdAt` (DESC)
   - Composé: `followedId` (ASC), `createdAt` (DESC)

3. Collection `interactions`:
   - Composé: `contentId` (ASC), `type` (ASC), `createdAt` (DESC)
   - Composé: `userId` (ASC), `type` (ASC), `createdAt` (DESC)

4. Collection `slots`:
   - Composé: `providerId` (ASC), `date` (ASC), `startTime` (ASC)
   - Composé: `serviceId` (ASC), `status` (ASC), `date` (ASC), `startTime` (ASC)

5. Collection `transactions`:
   - Composé: `customerId` (ASC), `createdAt` (DESC)
   - Composé: `providerId` (ASC), `status` (ASC), `createdAt` (DESC)
   - Composé: `type` (ASC), `status` (ASC), `createdAt` (DESC)

6. Collection `promotions`:
   - Composé: `code` (ASC), `active` (ASC), `validFrom` (ASC), `validUntil` (ASC)
   - Composé: `creatorId` (ASC), `active` (ASC), `validUntil` (DESC)

7. Collection `notifications`:
   - Composé: `userId` (ASC), `read` (ASC), `createdAt` (DESC)

## Conclusion

Cette structure Firestore complète est conçue pour soutenir efficacement toutes les fonctionnalités de votre application sociale et marketplace. Elle offre:

1. **Modularité**: Chaque type de contenu et d'interaction a sa propre structure définie
2. **Performance**: Des index appropriés pour les requêtes fréquentes
3. **Sécurité**: Règles d'accès strictes basées sur les rôles et l'appartenance
4. **Extensibilité**: Facilité d'ajout de nouveaux types de contenu ou de fonctionnalités
5. **Cohérence**: Utilisation de transactions et de batches pour maintenir l'intégrité des données

En suivant cette architecture, vous pourrez développer une application robuste qui supporte tous les cas d'utilisation mentionnés, des posts sociaux aux réservations de services, en passant par les commandes de produits et la gestion des promotions.
