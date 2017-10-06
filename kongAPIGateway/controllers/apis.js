const express = require('express');
const request = require('request-promise');
const httpStatus = require('http-status');
const router = express.Router();

router.get('/apis', (req, res) => {
  var option = {
    uri: process.env.KONG_URL + '/apis',
    method: 'GET',
    resolveWithFullResponse: true,
    json: true
  };

  request(option)
    .then(response => {
      return res.send(response.body);
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(error);
    });
});

router.post('/apis', (req, res) => {
  var option = {
    uri: process.env.KONG_URL + '/apis',
    method: 'POST',
    body: req.body,
    resolveWithFullResponse: true,
    json: true
  };

  request(option)
    .then(response => {
      return res.send(response.body);
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(error);
    });
});

router.put('/apis', (req, res) => {
  var option = {
    uri: process.env.KONG_URL + '/apis',
    method: 'PUT',
    body: req.body,
    resolveWithFullResponse: true,
    json: true
  };

  request(option)
    .then(response => {
      return res.send(response.body);
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(error);
    });
});

router.delete('/apis/:id', (req, res) => {
  var option = {
    uri: process.env.KONG_URL + '/apis/' + req.params.id,
    method: 'DELETE',
    resolveWithFullResponse: true,
    json: true
  };

  request(option)
    .then(response => {
      return res.send(response.body);
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(error);
    });
});

router.get('/apis/:id/plugins', (req, res) => {
  var option = {
    uri: process.env.KONG_URL + '/apis/' + req.params.id + '/plugins',
    method: 'GET',
    resolveWithFullResponse: true,
    json: true
  };

  request(option)
    .then(response => {
      return res.send(response.body);
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(error);
    });
});

router.post('/apis/:id/plugins', (req, res) => {
  req.body.config.oxd_host = process.env.OXD_WEB;
  var option = {
    uri: process.env.KONG_URL + '/apis/' + req.params.id + '/plugins',
    method: 'POST',
    body: req.body,
    resolveWithFullResponse: true,
    json: true
  };

  request(option)
    .then(response => {
      return res.send(response.body);
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(error);
    });
});

module.exports = router;