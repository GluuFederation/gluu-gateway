var express = require('express');
var app = express();
var server = require('http').Server(app);

// set up view engine
app.set('view engine', 'ejs');

// endpoints
app.get('/logout_redirect_uri', function (req, res) {
  res.render('logout');
});

app.get('/flights/', function (req, res) {
  res.render('flights');
});

app.get('/settings/', function (req, res) {
  res.render('settings');
});

app.get('/payments/', function (req, res) {
  res.render('payments');
});

app.get('/home/', function (req, res) {
  res.render('home');
});

app.get('/', function (req, res) {
  res.render('home');
});

app.use(function (err, req, res, next) {
  console.log(err.stack);
  if (err) {
    res.status(500).send({Error: err.stack});
  }
});

// Start server
server.listen(4400, function () {
  console.log('-----------------------\nServer started successfully!, Open this URL http://localhost:4400\n-----------------------');
});
