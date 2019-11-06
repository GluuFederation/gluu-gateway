const metrics = require('./metrics.model');

/**
 * Get all active metrics
 * @return {metrics} - return all metrics
 * @return {err} - return error
 */
let getMetricsBySearch = (params) => {
  return metrics
    .search(params)
    .then((metrics) => Promise.resolve(metrics))
    .catch((err) => Promise.reject(err));
};

/**
 * Get all active metrics
 * @return {metrics} - return all metrics
 * @return {err} - return error
 */
let getAllMetrics = () => {
  return metrics
    .find({})
    .sort({name: 1})
    .exec()
    .then((metrics) => Promise.resolve(metrics))
    .catch((err) => Promise.reject(err));
};

/**
 * Get metrics by Id
 * @param {ObjectId} id - metrics id
 * @return {metrics} - return metrics
 * @return {err} - return error
 */
let getMetricsById = (id) => {
  return metrics
    .findById(id)
    .exec()
    .then((metrics) => Promise.resolve(metrics))
    .catch((err) => Promise.reject(err));
};

/**
 * Register metrics
 * If already exist then update
 * @param {object} req - Request json object
 * @return {metrics} - return metrics
 * @return {err} - return error
 */
let registration = (req, id) => {
  return metrics
    .findOne({ metrics_host: req.metrics_host })
    .exec()
    .then((oMetrics) => {
      if (oMetrics) {
        oMetrics.email = req.email || oMetrics.email;
        oMetrics.metrics_host = req.metrics_host || oMetrics.metrics_host;
        oMetrics.organization = req.organization || oMetrics.organization;
      } else {
        oMetrics = new metrics();
        oMetrics.email = req.email;
        oMetrics.metrics_host = req.metrics_host;
        oMetrics.organization = req.organization;
      }

      return oMetrics.save()
        .then(updatedMetrics => Promise.resolve(updatedMetrics))
        .catch(err => Promise.reject(err));
    })
    .catch(err => Promise.reject(err));
};

/**
 * Add metrics
 * @param {object} req - Request json object
 * @return {metrics} - return metrics
 * @return {err} - return error
 */
let addMetrics = (req) => {
  let oMetrics = new metrics();
  oMetrics.email = req.email;
  oMetrics.metrics_host = req.metrics_host;
  oMetrics.organization = req.organization;

  return oMetrics.save()
    .then(metrics => Promise.resolve(metrics))
    .catch(err => Promise.reject(err));
};

/**
 * Update metrics
 * @param {object} req - Request json object
 * @return {metrics} - return metrics
 * @return {err} - return error
 */
let updateMetrics = (req, id) => {
  return metrics
    .findById(id)
    .exec()
    .then((oMetrics) => {
      oMetrics.email = req.email || oMetrics.email;
      oMetrics.metrics_host = req.metrics_host || oMetrics.metrics_host;
      oMetrics.organization = req.organization || oMetrics.organization;

      return oMetrics.save()
        .then(updatedMetrics => Promise.resolve(updatedMetrics))
        .catch(err => Promise.reject(err));
    })
    .catch(err => Promise.reject(err));
};

/**
 * Remove metrics by Id
 * @param {ObjectId} id - metrics id
 * @return {metrics} - return metrics
 * @return {err} - return error
 */
let removeMetrics = (id) => {
  return metrics
    .findById(id)
    .exec()
    .then((oMetrics) => {
      return oMetrics
        .remove()
        .then((rMetrics) => Promise.resolve(rMetrics))
        .catch(err => Promise.reject(err));
    })
    .catch(err => Promise.reject(err));
};

module.exports = {
  getAllMetrics,
  getMetricsById,
  addMetrics,
  updateMetrics,
  removeMetrics,
  getMetricsBySearch,
  registration
};
