const express = require('express');
const router = express.Router();
const metricsController = require('./metrics.controller');

router.route('/registration')
  .post(metricsController.registration);

module.exports = router;
