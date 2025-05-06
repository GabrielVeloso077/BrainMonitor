// functions/index.js

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Inicializa o Admin SDK apontando para seu Realtime DB
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  databaseURL: 'https://piloto-minas-laser.firebaseio.com'
});

// Função pública: lista até 1000 usuários do Auth sem exigir login
exports.listAllUsers = functions.https.onCall(async () => {
  const listUsersResult = await admin.auth().listUsers(1000);
  return listUsersResult.users.map(user => ({
    uid: user.uid,
    email: user.email || ''
  }));
});
