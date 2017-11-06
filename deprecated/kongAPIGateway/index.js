require('dotenv').config({path: './.env-dev'}); //for development
// require('dotenv').config({path: './.env-prod'}); // for production
const express = require('express'),
  app = express(),
  morgan = require('morgan'),
  bodyParser = require('body-parser'),
  path = require('path'),
  cors = require('cors'),
  server = require('http').Server(app),
  https = require('https'),
  tls = require('tls'),
  expressJwt = require('express-jwt'),
  fs = require('fs');

var options = {
  key: fs.readFileSync('key.pem'),
  cert: fs.readFileSync('cert.pem'),
  requestCert: true,
  rejectUnauthorized: false,
  ca: [fs.readFileSync('careq.pem')]
};

// Set port
app.set('port', process.env.PORT || 8000);

// Allow cross origin
app.use(cors());

// Logger
app.use(morgan('dev'));

// Validate each call before route
app.use('/', function (err, req, res, next) {
  next();
});

// Set directory for express
app.use(express.static(path.join(__dirname, 'public')));

let filter = function (req) {
  if (['/login'].indexOf(req.path) >= 0) {
    return true;
  } else if (req.path.startsWith('/isUserAlreadyExist')) {
    return true;
  }
};
app.use(expressJwt({secret: process.env.APP_SECRET}).unless(filter));

app.use('/', function (err, req, res, next) {
  if (err.name === 'UnauthorizedError') {
    res.status(401).send({
      'message': 'Please login again. Session expired.'
    });
    return;
  } else if (req.originalUrl !== '/login') {
    var authorization = req.header('authorization');
    if (authorization) {
      var session = JSON.parse(new Buffer((authorization.split(' ')[1]).split('.')[1], 'base64').toString());
      res.locals.session = session;
    }
  }
  next();
});

// Load body parser
app.use(bodyParser.json());
app.use(bodyParser.json({limit: '50mb'}));
app.use(bodyParser.urlencoded({limit: '50mb', extended: true}));

// For self-signed certificate.
process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

// Register routes. Loaded main route. Index route loads other routes.
app.use(require('./controllers/index'));
// Start listening server
// server.listen(process.env.PORT, () => {
//   console.log(`-----------------------\nServer started successfully!, Open this URL ${process.env.BASE_URL}\n-----------------------`);
// });

https.createServer(options, app).listen(process.env.PORT, () => {
  console.log(`-----------------------\nServer started successfully!, Open this URL ${process.env.BASE_URL}\n-----------------------`);
});
