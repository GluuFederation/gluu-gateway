const express = require('express'),
  router = express.Router();

/**
 * Default route.
 */
router.get('/health-check', (req, res) => res.status(200).send({
  message: 'Cool'
}));

router.use('/api/', require('./scripts'));
router.use('/api/', require('./scopes'));
router.use('/api/', require('./oxdweb'));
router.use('/api/', require('./apis'));
router.use('/', require('./login'));

module.exports = router;
