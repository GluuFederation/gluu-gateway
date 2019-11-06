require('dotenv').config();
const express = require('express');
const app = express();
const morgan = require('morgan');
const bodyParser = require('body-parser');
const cors = require('cors');
const mongoose = require('mongoose');
const https = require('https');
const fs = require('fs');

const server = require('http').Server(app);

// Set the ssl keys files to start server on https
const credentials = {
  key: fs.readFileSync(process.env.KEY_PEM).toString(),
  cert: fs.readFileSync(process.env.CERT_PEM).toString()
};

// MongoDB connection configuration
mongoose.Promise = global.Promise;
mongoose.connect(process.env.DB_URL, {useMongoClient: true}, (err, res) => {
  if (err)
    console.log(`err connecting to db on ${process.env.DB_URL}, err: ${err}`);
  else
    console.log(`----- Database connected on ${process.env.DB_URL} -----`);
}); // connect to our database

// Set port
app.set('port', process.env.PORT || 8000);

// Allow cross origin
app.use(cors());

// Logger
app.use(morgan('combined'));

// Middleware to check and allow only registration endpoint access
app.use('/', function (req, res, next) {
  if (req.path !== '/metrics/registration') {
    return res.status(403).send({
      'message': 'Not Allow to access ' + req.path
    });
  }
  next();
})

// Load body parser
app.use(bodyParser.json());

// For self-signed certificate.
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

// Register routes. Loaded main route. Index route loads other routes.
app.use(require('./index.route'));

//Start listening server
https.createServer(credentials, app).listen(process.env.PORT, () => {
  console.log(`-----------------------\nServer started successfully!, Open this URL ${process.env.BASE_URL}\n-----------------------`);
});
