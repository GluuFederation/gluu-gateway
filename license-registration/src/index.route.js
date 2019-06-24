const express = require('express');
const router = express.Router();
const metrics = require('./metrics/metrics.route');

/**
 * Default route.
 */
router.get('/health-check', (req, res) => res.status(200).send({
  message: 'Success'
}));

router.use('/metrics', metrics);

module.exports = router;
