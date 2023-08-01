# Build the flutter web app without minification and deploy to firebase.

flutter build web --dart2js-optimization=O1 && firebase deploy
