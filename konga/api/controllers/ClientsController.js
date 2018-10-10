'use strict';

var _ = require('lodash');
var httpRequest = require('request-promise');

/**
 * ClientsController - Used to manage OP client for plugins
 *
 * @description :: Server-side logic for managing Users
 * @help        :: See http://links.sailsjs.org/docs/controllers
 */
module.exports = _.merge(_.cloneDeep(require('../base/Controller')), {

  // User to register client for OAuth plugin
  addOAuthClient: function (req, res) {
    // Existing client id and secret
    if (req.body.oxd_id && req.body.client_id && req.body.client_secret) {
      return res.send({oxd_id: req.body.oxd_id, client_id: req.body.client_id, client_secret: req.body.client_secret})
    }

    // Create new client
    const option = {
      method: 'POST',
      uri: sails.config.oxdWeb + '/register-site',
      body: {
        op_host: sails.config.opHost,
        authorization_redirect_uri: 'https://client.example.com/cb',
        client_name: req.body.client_name || 'gluu-oauth-client',
        client_id: req.body.client_id || '',
        client_secret: req.body.client_secret || '',
        grant_types: ['client_credentials'],
      },
      resolveWithFullResponse: true,
      json: true
    };

    return httpRequest(option)
      .then(function (response) {
        var clientInfo = response.body.data;
        return res.send({
          oxd_id: clientInfo.oxd_id,
          client_id: clientInfo.client_id,
          client_secret: clientInfo.client_secret
        })
      })
      .catch(function (error) {
        return res.status(500).send(error);
      });
  },

  // Register OP client and register UMA resources
  registerClientAndResources: function (req, res) {
    // Existing client id and secret
    if (!req.body.uma_scope_expression) {
      return res.status(400).send({message: "uma_scope_expression is required"});
    }
    var opClient;
    registerClient()
      .then(function (clientInfo) {
        opClient = clientInfo;
        if (!clientInfo.client_id && !clientInfo.client_secret && !clientInfo.oxd_id) {
          console.log("Failed to register client", clientInfo);
          return res.status(500).send({message: "Failed to register client"});
        }

        var option = {
          method: 'POST',
          uri: sails.config.oxdWeb + '/get-client-token',
          body: {
            op_host: sails.config.opHost,
            client_id: sails.config.clientId,
            client_secret: sails.config.clientSecret,
            scope: ['openid', 'uma_protection']
          },
          resolveWithFullResponse: true,
          json: true
        };

        return httpRequest(option);
      })
      .then(function (response) {
        var clientToken = response.body.data;
        var option = {
          method: 'POST',
          uri: sails.config.oxdWeb + '/uma-rs-protect',
          body: {
            oxd_id: opClient.oxd_id,
            resources: req.body.uma_scope_expression
          },
          headers: {
            Authorization: 'Bearer ' + clientToken.access_token
          },
          resolveWithFullResponse: true,
          json: true
        };

        return httpRequest(option);
      })
      .then(function (response) {
        var umaProtect = response.body.data;
        if (!umaProtect.oxd_id) {
          console.log("Failed to register resources", response);
          return res.status(500).send({message: "Failed to register resources"});
        }

        return res.status(200).send({
          oxd_id: umaProtect.oxd_id,
          client_id: opClient.client_id,
          client_secret: opClient.client_secret
        });
      })
      .catch(function (error) {
        console.log(error);
        return res.status(500).send(error);
      });

    function registerClient() {
      return new Promise(function (resolve, reject) {
        if (req.body.oxd_id && req.body.client_id && req.body.client_secret) {
          return resolve({
            oxd_id: req.body.oxd_id,
            client_id: req.body.client_id,
            client_secret: req.body.client_secret
          })
        }

        // Create new client
        const option = {
          method: 'POST',
          uri: sails.config.oxdWeb + '/register-site',
          body: {
            op_host: sails.config.opHost,
            authorization_redirect_uri: 'https://client.example.com/cb',
            client_name: req.body.client_name || 'gluu-uma-client',
            client_id: req.body.client_id || '',
            client_secret: req.body.client_secret || '',
            scope: ['openid', 'uma_protection'],
            grant_types: ['client_credentials'],
          },
          resolveWithFullResponse: true,
          json: true
        };

        return httpRequest(option)
          .then(function (response) {
            var clientInfo = response.body.data;
            return resolve({
              oxd_id: clientInfo.oxd_id,
              client_id: clientInfo.client_id,
              client_secret: clientInfo.client_secret
            })
          })
          .catch(function (error) {
            console.log(error);
            return reject(error);
          });
      });
    }
  }
});
