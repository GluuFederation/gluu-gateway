const express = require('express');
const request = require('request-promise');
const httpStatus = require('http-status');
const router = express.Router();

router.post('/health-check', (req, res) => {
  request(req.body.url)
    .then(response => {
      return res.send(response);
    })
    .catch(error => {
      return res.status(httpStatus.INTERNAL_SERVER_ERROR).send(error);
    });
});

module.exports = router;