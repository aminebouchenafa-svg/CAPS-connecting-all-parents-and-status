# C.A.P.S. - Connecting All Parents & Status

Cockpit Familial pour pilotes. Suivez votre statut opérationnel en temps réel et partagez un calendrier familial.

## Setup rapide

```bash
# 1. Clone et entre dans le projet
git clone https://github.com/aminebouchenafa-svg/caps-connecting-all-parents-and-status.git
cd caps-connecting-all-parents-and-status
git checkout claude/caps-flutter-architecture-bqskkk

# 2. Lance le script de setup
./setup.sh

# 3. Configure Firebase
dart pub global activate flutterfire_cli
flutterfire configure

# 4. Lance l'app
flutter run -d chrome
```

## Setup Firebase (obligatoire)

1. Crée un projet sur [Firebase Console](https://console.firebase.google.com)
2. Active **Authentication > Email/Password**
3. Crée **Cloud Firestore** (mode test)
4. Lance `flutterfire configure` pour générer les clés
5. Crée un utilisateur dans Authentication
6. Ajoute son profil dans Firestore :

```
Collection: users/{UID}
{
  "email": "amine@example.com",
  "displayName": "Amine",
  "role": "pilot",
  "householdId": "famille-bouchenafa",
  "createdAt": <timestamp>
}
```

Pour ajouter Amina (conjointe) :
```
Collection: users/{UID_AMINA}
{
  "email": "amina@example.com",
  "displayName": "Amina",
  "role": "spouse",
  "householdId": "famille-bouchenafa",
  "createdAt": <timestamp>
}
```

## Architecture

```
lib/
├── config/         # Firebase config + Routes (GoRouter)
├── core/           # Theme, widgets réutilisables, erreurs, extensions
└── features/
    ├── auth/       # Authentification Email/Password
    ├── dashboard/  # Statut pilote temps réel + countdown
    └── calendar/   # Calendrier familial partagé
```

Chaque feature : `domain/` (entities, repositories) → `data/` (models, datasources) → `presentation/` (pages, providers, widgets)

## Stack

- **Flutter 3.29+** / Dart 3.7+
- **Firebase** (Auth, Firestore)
- **Riverpod** (state management)
- **GoRouter** (navigation)
- **Clean Architecture**
