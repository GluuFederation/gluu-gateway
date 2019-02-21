/**
 * RemoteApiController
 */

var unirest = require("unirest")

module.exports = {


  /**
   * Proxy requests to native Kong Admin API
   * @param req
   * @param res
   */
  proxy: function (req, res) {

    req.url = req.url.replace('/kong', ''); // Remove the /api prefix

    // Fix update method by setting it to "PATCH"
    // as Kong requires
    if (req.method.toLowerCase() == 'put') {
      req.method = "PATCH"
    }
    var headers = {'Content-Type': 'application/json'};

    // If apikey is set in headers, use it
    // if (req.kong_api_key) {
    //   headers['apikey'] = req.kong_api_key
    // }

    var request = unirest[req.method.toLowerCase()](req.connection.kong_admin_url + req.url);
    request.headers(headers);
    if (['post', 'put', 'patch'].indexOf(req.method.toLowerCase()) > -1) {

      if (req.body && req.body.orderlist) {
        for (var i = 0; i < req.body.orderlist.length; i++) {
          try {
            req.body.orderlist[i] = parseInt(req.body.orderlist[i])
          } catch (err) {
            return res.badRequest({
              body: {
                message: 'Ordelist entities must be integers'
              }
            })
          }
        }
      }
    }

    request.send(req.body);
    sails.log(new Date(), "--------------Kong API Call----------------");
    if (req.body && Object.keys(req.body).length > 0) {
      sails.log(new Date(), ` $ curl -k -X ${req.method.toUpperCase()} ${req.connection.kong_admin_url + req.url} -d '${JSON.stringify(req.body)}'`);
    } else {
      sails.log(new Date(), ` $ curl -k -X ${req.method.toUpperCase()} ${req.connection.kong_admin_url + req.url}`);
    }

    request.end(function (response) {
      if (response.error)  return res.negotiate(response);
      return res.json(response.body)
    })
  }
};