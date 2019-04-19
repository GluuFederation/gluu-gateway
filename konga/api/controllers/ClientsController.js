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

  // Register client
  opDiscovery: function (req, res) {
    if (!req.body.op_url) {
      return res.status(400).send({message: "OP Server URL is required"});
    }

    const op_discovery_url = req.body.op_url + '/.well-known/openid-configuration'
    const option = {
      method: 'POST',
      uri: op_discovery_url,
      resolveWithFullResponse: true,
      json: true
    };

    return httpRequest(option)
      .then(function (response) {
        res.send(response.body);
      })
      .catch(function (error) {
        sails.log(new Date(), '----- Error OP Discovery -----', op_discovery_url, error);
        return res.status(500).send(error);
      });
  },

  // Register client
  registerClient: function (clientRequest) {
    return new Promise(function (resolve, reject) {
      // Create new client
      const option = {
        method: 'POST',
        uri: clientRequest.oxd_url + '/register-site',
        body: {
          op_host: clientRequest.op_host || sails.config.opHost,
          authorization_redirect_uri: clientRequest.authorization_redirect_uri || 'https://client.example.com/cb',
          client_name: clientRequest.client_name || 'gg-client',
          client_id: clientRequest.client_id || '',
          client_secret: clientRequest.client_secret || '',
          scope: clientRequest.scope || ['openid', 'oxd'],
          grant_types: clientRequest.grant_types || ['client_credentials'],
          access_token_as_jwt: clientRequest.access_token_as_jwt || false,
          rpt_as_jwt: clientRequest.rpt_as_jwt || false,
          access_token_signing_alg: clientRequest.access_token_signing_alg || 'RS256',
        },
        resolveWithFullResponse: true,
        json: true
      };

      sails.log(new Date(), "--------------OXD API Call----------------");
      sails.log(new Date(), ` $ curl -k -X POST ${clientRequest.oxd_url + '/register-site'} -d '${JSON.stringify(option.body)}'`);

      return httpRequest(option)
        .then(function (response) {
          var clientInfo = response.body;
          return resolve({
            oxd_id: clientInfo.oxd_id,
            client_id: clientInfo.client_id,
            client_secret: clientInfo.client_secret
          })
        })
        .catch(function (error) {
          sails.log(new Date(), '----- Error Client registration -----', error);
          return reject(error);
        });
    });
  },

  // Get Client info
  getClient: function (req, res) {
    return sails.models.client
      .findOne({
        oxd_id: req.params.oxd_id
      })
      .then(function (oClient) {
        if (!oClient) {
          sails.log(new Date(), "Failed to fetch client data");
          return res.status(500).send("Failed to fetch client data");
        }

        return res.status(200).send(oClient);
      })
      .catch(function (error) {
        sails.log(new Date(), error);
        return res.status(500).send("Failed to fetch client data");
      });
  },

  // User to register client for OAuth plugin
  addGluuClientAuth: function (req, res) {
    // Existing client id and secret
    const body = req.body;

    if (body.oxd_id && body.client_id && body.client_secret) {
      return res.send({oxd_id: body.oxd_id, client_id: body.client_id, client_secret: body.client_secret})
    }

    if (!body.op_host) {
      return res.status(400).send({message: "OP Server is required"});
    }

    if (!body.oxd_url) {
      return res.status(400).send({message: "OXD Server is required"});
    }

    // Create new client
    const option = {
      op_host: body.op_host,
      oxd_url: body.oxd_url,
      authorization_redirect_uri: 'https://client.example.com/cb',
      client_name: body.client_name || 'gg-oauth-client',
      client_id: body.client_id || '',
      client_secret: body.client_secret || ''
    };

    return this.registerClient(option)
      .then(function (clientInfo) {
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
  addGluuUMAPEP: function (req, res) {
    const body = req.body;
    // Existing client id and secret
    if (!body.uma_scope_expression) {
      return res.status(400).send({message: "uma_scope_expression is required"});
    }

    if (!body.op_host) {
      return res.status(400).send({message: "OP Server is required"});
    }

    if (!body.oxd_url) {
      return res.status(400).send({message: "OXD Server is required"});
    }

    var opClient;
    var that = this;
    new Promise(function (resolve, reject) {
      if (body.oxd_id && body.client_id && body.client_secret) {
        return resolve({
          oxd_id: body.oxd_id,
          client_id: body.client_id,
          client_secret: body.client_secret
        })
      } else {
        const option = {
          op_host: body.op_host,
          oxd_url: body.oxd_url,
          authorization_redirect_uri: 'https://client.example.com/cb',
          client_name: body.client_name || 'gg-uma-client',
          client_id: body.client_id || '',
          client_secret: body.client_secret || '',
          scope: ['openid', 'oxd', 'uma_protection'],
          grant_types: ['client_credentials'],
        };

        return that.registerClient(option)
          .then(function (clientInfo) {
            return resolve(clientInfo);
          })
          .catch(function (error) {
            return resolve(error);
          });
      }
    })
      .then(function (clientInfo) {
        opClient = clientInfo;
        if (!clientInfo.client_id && !clientInfo.client_secret && !clientInfo.oxd_id) {
          sails.log(new Date(), "Failed to register client", clientInfo);
          return Promise.reject({message: "Failed to register client"});
        }

        var option = {
          method: 'POST',
          uri: body.oxd_url + '/get-client-token',
          body: {
            op_host: body.op_host,
            client_id: opClient.client_id,
            client_secret: opClient.client_secret,
            scope: ['openid', 'oxd']
          },
          resolveWithFullResponse: true,
          json: true
        };

        sails.log(new Date(), "--------------OXD API Call----------------");
        sails.log(new Date(), ` $ curl -k -X POST ${body.oxd_url + '/get-client-token'} -d '${JSON.stringify(option.body)}'`);

        return httpRequest(option);
      })
      .then(function (response) {
        var clientToken = response.body;
        var option = {
          method: 'POST',
          uri: body.oxd_url + '/uma-rs-protect',
          body: {
            oxd_id: opClient.oxd_id,
            resources: body.uma_scope_expression
          },
          headers: {
            Authorization: 'Bearer ' + clientToken.access_token
          },
          resolveWithFullResponse: true,
          json: true
        };

        sails.log(new Date(), "--------------OXD API Call----------------");
        sails.log(new Date(), ` $ curl -k -X POST ${body.oxd_url + '/uma-rs-protect'} -H 'Authorization: Bearer ${clientToken.access_token}' -d '${JSON.stringify(option.body)}'`);

        return httpRequest(option);
      })
      .then(function (response) {
        var umaProtect = response.body;
        if (!umaProtect.oxd_id) {
          sails.log(new Date(), "Failed to register resources", response);
          return Promise.reject({message: "Failed to register resources"});
        }

        return sails.models.client
          .create({
            oxd_id: umaProtect.oxd_id,
            client_id: opClient.client_id,
            client_secret: opClient.client_secret,
            context: 'GLUU-UMA-PEP',
            data: body.uma_scope_expression
          })
      })
      .then(function (dbClient) {
        if (!dbClient.oxd_id) {
          sails.log(new Date(), "Failed to add client and resources in konga db", dbClient);
          return Promise.reject({message: "Failed to add client and resources in konga db"});
        }

        return res.status(200).send({
          oxd_id: dbClient.oxd_id,
          client_id: opClient.client_id,
          client_secret: opClient.client_secret
        });
      })
      .catch(function (error) {
        sails.log(new Date(), '---- registerClientAndResources ----', error);
        return res.status(500).send(error);
      });
  },

  // add client for consumer
  addConsumerClient: function (req, res) {
    const body = req.body;
    var opClient;
    // Create new client
    const option = {
      op_host: body.op_host,
      oxd_url: body.oxd_url,
      authorization_redirect_uri: 'https://client.example.com/cb',
      client_name: body.client_name || 'gg-oauth-consumer-client',
      client_id: body.client_id || '',
      client_secret: body.client_secret || '',
      access_token_as_jwt: body.access_token_as_jwt || false,
      rpt_as_jwt: body.rpt_as_jwt || false,
      access_token_signing_alg: body.access_token_signing_alg || 'RS256',
    };

    this.registerClient(option)
      .then(function (clientInfo) {
        opClient = clientInfo;
        if (!clientInfo.client_id && !clientInfo.client_secret && !clientInfo.oxd_id) {
          sails.log(new Date(), "Failed to register client", clientInfo);
          return Promise.reject({message: "Failed to register client"});
        }

        return sails.models.client
          .create({
            oxd_id: clientInfo.oxd_id,
            client_id: clientInfo.client_id,
            client_secret: clientInfo.client_secret,
            context: 'CONSUMER'
          })
      })
      .then(function (dbClient) {
        if (!dbClient.oxd_id) {
          sails.log(new Date(), "Failed to add client and resources in konga db", dbClient);
          return Promise.reject({message: "Failed to add client and resources in konga db"});
        }

        return res.status(200).send({
          oxd_id: dbClient.oxd_id,
          client_id: opClient.client_id,
          client_secret: opClient.client_secret
        });
      })
      .catch(function (error) {
        sails.log(new Date(), '--- addOAuthConsumerClient ---', error);
        return res.status(500).send(error);
      });
  },

  // User to register client for OpenID Connect plugin
  addOPClient: function (req, res) {
    const body = req.body;

    if (!body.op_host) {
      return res.status(400).send({message: "OP Server is required"});
    }

    if (!body.oxd_url) {
      return res.status(400).send({message: "OXD Server is required"});
    }

    if (!body.comment) {
      return res.status(400).send({message: "Comment is required"});
    }

    if (!body.max_id_token_age_value) {
      return res.status(400).send({message: "max_id_token_age_value is required"});
    }

    if (!body.max_id_token_age_type) {
      return res.status(400).send({message: "max_id_token_age_type is required"});
    }

    if (!body.max_id_token_auth_age_value) {
      return res.status(400).send({message: "max_id_token_auth_age_value is required"});
    }

    if (!body.max_id_token_auth_age_type) {
      return res.status(400).send({message: "max_id_token_auth_age_type is required"});
    }

    // Create new client
    const reqBody = {
      op_host: body.op_host,
      oxd_url: body.oxd_url,
      authorization_redirect_uri: body.authorization_redirect_uri || 'https://client.example.com/cb',
      client_name: body.client_name || 'gg-openid-connect-client',
      post_logout_redirect_uri: body.post_logout_redirect_uri,
      scope: body.scope,
      acr_values: body.acr_values,
      grant_types: ['client_credentials', 'authorization_code', 'refresh_token'],
      claims_redirect_uri: body.claims_redirect_uri || [],
    };

    const option = {
      method: 'POST',
      uri: reqBody.oxd_url + '/register-site',
      body: reqBody,
      resolveWithFullResponse: true,
      json: true
    };
    var dbOPClient;
    return httpRequest(option)
      .then(function (response) {
        var clientInfo = response.body;
        return sails.models.client
          .create({
            oxd_id: clientInfo.oxd_id,
            client_id: clientInfo.client_id,
            client_secret: clientInfo.client_secret,
            context: 'GLUU-OPENID-CONNECT',
            data: {
              uma_scope_expression: body.uma_scope_expression,
              max_id_token_age: {
                value: body.max_id_token_age_value,
                type: body.max_id_token_age_type,
              },
              max_id_token_auth_age: {
                value: body.max_id_token_auth_age_value,
                type: body.max_id_token_auth_age_type,
              }
            }
          })
      })
      .then(function (dbClient) {
        if (!dbClient.oxd_id) {
          sails.log(new Date(), "Failed to add client and resources in konga db", dbClient);
          return Promise.reject({message: "Failed to add client and resources in konga db"});
        }

        dbOPClient = dbClient;
        return sails.models.auditlog
          .create({
            comment: body.comment,
            route_id: body.route_id
          })
      })
      .then(function (auditlog) {
        if (!auditlog.comment) {
          sails.log(new Date(), "Failed to add log", auditlog);
          return Promise.reject({message: "Failed to add log"});
        }

        return res.send({
          oxd_id: dbOPClient.oxd_id,
          client_id: dbOPClient.client_id,
          client_secret: dbOPClient.client_secret
        })
      })
      .catch(function (error) {
        return res.status(500).send(error);
      });
  },

  // Update UMA resources
  updateGluuUMAPEP: function (req, res) {
    const body = req.body;
    // Existing client id and secret
    if (!body.uma_scope_expression) {
      return res.status(400).send({message: "uma_scope_expression is required"});
    }

    if (!body.oxd_id) {
      sails.log(new Date(), "Provide oxd_id to update resources");
      return res.status(500).send({message: "Provide oxd_id to update resources"});
    }

    if (!body.client_id) {
      sails.log(new Date(), "Provide client_id to update resources");
      return res.status(500).send({message: "Provide client_id to update resources"});
    }

    if (!body.client_secret) {
      sails.log(new Date(), "Provide oxd_id to update resources");
      return res.status(500).send({message: "Provide client_secret to update resources"});
    }

    var option = {
      method: 'POST',
      uri: body.oxd_url + '/get-client-token',
      body: {
        op_host: body.op_host,
        client_id: body.client_id,
        client_secret: body.client_secret,
        scope: ['openid', 'oxd']
      },
      resolveWithFullResponse: true,
      json: true
    };

    sails.log(new Date(), "--------------OXD API Call----------------");
    sails.log(new Date(), ` $ curl -k -X POST ${body.oxd_url + '/get-client-token'} -d '${JSON.stringify(option.body)}'`);

    return httpRequest(option)
      .then(function (response) {
        var clientToken = response.body;
        var option = {
          method: 'POST',
          uri: body.oxd_url + '/uma-rs-protect',
          body: {
            oxd_id: body.oxd_id,
            resources: body.uma_scope_expression,
            overwrite: true,
          },
          headers: {
            Authorization: 'Bearer ' + clientToken.access_token
          },
          resolveWithFullResponse: true,
          json: true
        };

        sails.log(new Date(), "--------------OXD API Call----------------");
        sails.log(new Date(), ` $ curl -k -X POST ${body.oxd_url + '/uma-rs-protect'} -H 'Authorization: Bearer ${clientToken.access_token}' -d '${JSON.stringify(option.body)}'`);

        return httpRequest(option);
      })
      .then(function (response) {
        var umaProtect = response.body;
        if (!umaProtect.oxd_id) {
          sails.log(new Date(), "Failed to update resources", response);
          return Promise.reject({message: "Failed to update resources"});
        }

        return sails.models.client
          .update({
            oxd_id: umaProtect.oxd_id
          }, {
            data: body.uma_scope_expression
          });
      })
      .then(function (dbClient) {
        if (dbClient.length < 1) {
          sails.log(new Date(), "Failed to update client in konga db", dbClient);
          return Promise.reject({message: "Failed to update client in konga db"});
        }
        return res.status(200).send({
          oxd_id: body.oxd_id
        });
      })
      .catch(function (error) {
        sails.log(new Date(), error);
        return res.status(500).send(error);
      });
  },

  // User to update client for OpenID Connect plugin
  updateOPClient: function (req, res) {
    // Existing client id and secret
    const body = req.body;

    if (!body.op_host) {
      return res.status(400).send({message: "OP Server is required"});
    }

    if (!body.oxd_id) {
      sails.log(new Date(), "Provide oxd_id to update resources");
      return res.status(500).send({message: "Provide oxd_id to update resources"});
    }

    if (!body.client_id) {
      sails.log(new Date(), "Provide client_id to update resources");
      return res.status(500).send({message: "Provide client_id to update resources"});
    }

    if (!body.client_secret) {
      sails.log(new Date(), "Provide oxd_id to update resources");
      return res.status(500).send({message: "Provide client_secret to update resources"});
    }

    if (!body.extraData) {
      sails.log(new Date(), "extraData required!");
      return res.status(500).send({message: "extraData required!"});
    }

    if (!body.oxd_url) {
      return res.status(400).send({message: "OXD Server is required"});
    }

    if (!body.comment) {
      return res.status(400).send({message: "Comment is required"});
    }

    var option = {
      method: 'POST',
      uri: body.oxd_url + '/get-client-token',
      body: {
        op_host: body.op_host,
        client_id: body.client_id,
        client_secret: body.client_secret,
        scope: ['openid', 'oxd']
      },
      resolveWithFullResponse: true,
      json: true
    };
    sails.log(new Date(), "--------------OXD API Call----------------");
    sails.log(new Date(), ` $ curl -k -X POST ${body.oxd_url + '/get-client-token'} -d '${JSON.stringify(option.body)}'`);

    return httpRequest(option)
      .then(function (response) {
        var clientToken = response.body;

        // Create new client
        const reqBody = {
          oxd_id: body.oxd_id,
          op_host: body.op_host,
          oxd_url: body.oxd_url,
          authorization_redirect_uri: body.authorization_redirect_uri || 'https://client.example.com/cb',
          post_logout_redirect_uri: body.post_logout_redirect_uri,
          scope: body.scope,
          acr_values: body.acr_values,
          grant_types: ['client_credentials', 'authorization_code', 'refresh_token'],
          claims_redirect_uri: body.claims_redirect_uri || [],
        };

        const option = {
          method: 'POST',
          uri: reqBody.oxd_url + '/update-site',
          body: reqBody,
          headers: {
            Authorization: 'Bearer ' + clientToken.access_token
          },
          resolveWithFullResponse: true,
          json: true
        };

        sails.log(new Date(), "--------------OXD API Call----------------");
        sails.log(new Date(), ` $ curl -k -X POST ${body.oxd_url + '/update-site'} -H 'Authorization: Bearer ${clientToken.access_token}' -d '${JSON.stringify(option.body)}'`);

        return httpRequest(option)
      })
      .then(function (response) {
        var updateSite = response.body;
        if (!updateSite.oxd_id) {
          sails.log(new Date(), "Failed to update resources", response);
          return Promise.reject({message: "Failed to update resources"});
        }

        return sails.models.client
          .update({
            oxd_id: body.oxd_id
          }, {
            data: body.extraData
          });
      })
      .then(function (dbClient) {
        if (dbClient.length < 1) {
          sails.log(new Date(), "Failed to update client in konga db", dbClient);
          return Promise.reject({message: "Failed to update client in konga db"});
        }
        return sails.models.auditlog
          .create({
            comment: body.comment,
            route_id: body.route_id
          })
      })
      .then(function (auditlog) {
        if (!auditlog.comment) {
          sails.log(new Date(), "Failed to add log", auditlog);
          return Promise.reject({message: "Failed to add log"});
        }

        return res.send({
          oxd_id: body.oxd_id
        })
      })
      .catch(function (error) {
        return res.status(500).send(error);
      });
  },

  // delete consumer client
  deleteConsumerClient: function (req, res) {
    var kongaDBClient;
    // doWantDeleteClient=true Delete client from GG and OXD
    if (req.params.doWantDeleteClient == "true") {
      return sails.models.client
        .findOne({
          client_id: req.params.client_id
        })
        .then(function (oClient) {
          kongaDBClient = oClient;

          if (!kongaDBClient) {
            sails.log(new Date(), "Client does not exists in GG");
            return Promise.reject({message: "Client does not exists in GG"});
          }

          if (kongaDBClient.oxd_id == sails.config.oxdId) {
            sails.log(new Date(), "Not allow to delete GG Admin login client");
            return Promise.reject({message: "Not allow to delete GG Admin login client"});
          }

          var option = {
            method: 'POST',
            uri: sails.config.oxdWeb + '/get-client-token',
            body: {
              op_host: sails.config.opHost,
              client_id: kongaDBClient.client_id,
              client_secret: kongaDBClient.client_secret,
              scope: ['openid', 'oxd']
            },
            resolveWithFullResponse: true,
            json: true
          };

          sails.log(new Date(), "--------------OXD API Call----------------");
          sails.log(new Date(), ` $ curl -k -X POST ${sails.config.oxdWeb + '/get-client-token'} -d '${JSON.stringify(option.body)}'`);

          return httpRequest(option);
        })
        .then(function (response) {
          var clientToken = response.body;

          var option = {
            method: 'POST',
            uri: sails.config.oxdWeb + '/remove-site',
            body: {
              oxd_id: kongaDBClient.oxd_id
            },
            headers: {
              Authorization: 'Bearer ' + clientToken.access_token
            },
            resolveWithFullResponse: true,
            json: true
          };

          sails.log(new Date(), "--------------OXD API Call----------------");
          sails.log(new Date(), ` $ curl -k -X POST ${sails.config.oxdWeb + '/remove-site'} -H 'Authorization: Bearer ${clientToken.access_token}' -d '${JSON.stringify(option.body)}'`);

          return httpRequest(option);
        })
        .then(function (response) {
          var deletedClient = response.body;

          if (!deletedClient.oxd_id) {
            sails.log(new Date(), 'Failed to delete client from OXD', deletedClient);
            return Promise.reject({message: "Failed to delete client from OXD"});
          }

          return sails.models.client
            .destroy({
              oxd_id: deletedClient.oxd_id
            });
        })
        .then(function (deletedClient) {
          if (deletedClient.length <= 0) {
            sails.log(new Date(), 'Failed to delete client from GG', deletedClient);
            return Promise.reject({message: "Failed to delete client from GG"});
          }

          return res.status(200).send(deletedClient);
        })
        .catch(function (error) {
          sails.log(new Date(), error);
          return res.status(500).send(error);
        });
    }

    // doWantDeleteClient=false Delete client from GG
    return sails.models.client
      .findOne({
        client_id: req.params.client_id
      })
      .then(function (oClient) {
        if (oClient) {
          // delete client from GG
          sails.models.client
            .destroy({oxd_id: oClient.oxd_id})
            .then(function (deleteClient) {
              sails.log(new Date(), 'deleteClient:', deleteClient);
            });
        }
        return res.status(200).send();
      })
      .catch(function (error) {
        sails.log(new Date(), error);
        return res.status(500).send(error);
      });
  },

  // delete client from oxd for client-auth plugin
  deleteGluuClientAuth: function (req, res) {
    const body = req.body;

    if (!body.oxd_id) {
      sails.log(new Date(), "Provide oxd_id to update resources");
      return res.status(500).send({message: "Provide oxd_id to update resources"});
    }

    if (!body.client_id) {
      sails.log(new Date(), "Provide client_id to update resources");
      return res.status(500).send({message: "Provide client_id to update resources"});
    }

    if (!body.client_secret) {
      sails.log(new Date(), "Provide oxd_id to update resources");
      return res.status(500).send({message: "Provide client_secret to update resources"});
    }

    var option = {
      method: 'POST',
      uri: sails.config.oxdWeb + '/get-client-token',
      body: {
        op_host: sails.config.opHost,
        client_id: body.client_id,
        client_secret: body.client_secret,
        scope: ['openid', 'oxd']
      },
      resolveWithFullResponse: true,
      json: true
    };

    sails.log(new Date(), "--------------OXD API Call----------------");
    sails.log(new Date(), ` $ curl -k -X POST ${sails.config.oxdWeb + '/get-client-token'} -d '${JSON.stringify(option.body)}'`);

    return httpRequest(option)
      .then(function (response) {
        var clientToken = response.body;

        if (body.oxd_id == sails.config.oxdId) {
          sails.log(new Date(), "Not allow to delete GG Admin login client");
          return Promise.reject({message: "Not allow to delete GG Admin login client"});
        }

        var option = {
          method: 'POST',
          uri: sails.config.oxdWeb + '/remove-site',
          body: {
            oxd_id: body.oxd_id
          },
          headers: {
            Authorization: 'Bearer ' + clientToken.access_token
          },
          resolveWithFullResponse: true,
          json: true
        };

        sails.log(new Date(), "--------------OXD API Call----------------");
        sails.log(new Date(), ` $ curl -k -X POST ${sails.config.oxdWeb + '/remove-site'} -H 'Authorization: Bearer ${clientToken.access_token}' -d '${JSON.stringify(option.body)}'`);

        return httpRequest(option);
      })
      .then(function (response) {
        var deletedClient = response.body;

        if (!deletedClient.oxd_id) {
          sails.log(new Date(), 'Failed to delete client from oxd', deletedClient);
          return Promise.reject({message: 'Failed to delete client from oxd'});
        }

        return res.status(200).send(deletedClient);
      })
      .catch(function (error) {
        sails.log(new Date(), error);
        return res.status(500).send(error);
      });
  },

  // delete client from oxd for PEP plugin
  deleteGluuUMAPEP: function (req, res) {
    var kongaDBClient;

    // doWantDeleteClient=true Delete client from GG and OXD
    if (req.params.doWantDeleteClient == "true") {
      return sails.models.client
        .findOne({
          oxd_id: req.params.oxd_id
        })
        .then(function (oClient) {
          kongaDBClient = oClient;
          if (!kongaDBClient) {
            sails.log(new Date(), "Client does not exists in GG");
            return Promise.reject({message: "Client does not exists in GG"});
          }

          if (kongaDBClient.oxd_id == sails.config.oxdId) {
            sails.log(new Date(), "Not allow to delete GG Admin login client");
            return Promise.reject({message: "Not allow to delete GG Admin login client"});
          }

          var option = {
            method: 'POST',
            uri: sails.config.oxdWeb + '/get-client-token',
            body: {
              op_host: sails.config.opHost,
              client_id: kongaDBClient.client_id,
              client_secret: kongaDBClient.client_secret,
              scope: ['openid', 'oxd']
            },
            resolveWithFullResponse: true,
            json: true
          };

          sails.log(new Date(), "--------------OXD API Call----------------");
          sails.log(new Date(), ` $ curl -k -X POST ${sails.config.oxdWeb + '/get-client-token'} -d '${JSON.stringify(option.body)}'`);

          return httpRequest(option);
        })
        .then(function (response) {
          var clientToken = response.body;

          var option = {
            method: 'POST',
            uri: sails.config.oxdWeb + '/remove-site',
            body: {
              oxd_id: kongaDBClient.oxd_id
            },
            headers: {
              Authorization: 'Bearer ' + clientToken.access_token
            },
            resolveWithFullResponse: true,
            json: true
          };

          sails.log(new Date(), "--------------OXD API Call----------------");
          sails.log(new Date(), ` $ curl -k -X POST ${sails.config.oxdWeb + '/remove-site'} -H 'Authorization: Bearer ${clientToken.access_token}' -d '${JSON.stringify(option.body)}'`);

          return httpRequest(option);
        })
        .then(function (response) {
          var deletedClient = response.body;

          if (!deletedClient.oxd_id) {
            sails.log(new Date(), 'Failed to delete client from oxd', deletedClient);
            return Promise.reject({message: "Failed to delete client from oxd"});
          }
          return sails.models.client
            .destroy({
              oxd_id: deletedClient.oxd_id
            });
        })
        .then(function (deletedClient) {
          if (deletedClient.length <= 0) {
            sails.log(new Date(), 'Failed to delete client from GG', deletedClient);
            return Promise.reject({message: "Failed to delete client from GG"});
          }

          return res.status(200).send(deletedClient);
        })
        .catch(function (error) {
          sails.log(new Date(), error);
          return res.status(500).send(error);
        });
    }

    // doWantDeleteClient=false Delete client from GG
    return sails.models.client
      .findOne({
        oxd_id: req.params.oxd_id
      })
      .then(function (oClient) {
        if (oClient) {
          // delete client from GG
          sails.models.client
            .destroy({oxd_id: oClient.oxd_id})
            .then(function (deleteClient) {
              sails.log(new Date(), 'deleteClient:', deleteClient);
            });
        }
        return res.status(200).send();
      })
      .catch(function (error) {
        sails.log(new Date(), error);
        return res.status(500).send(error);
      });
  },

  // User to update client for OpenID Connect plugin
  deleteOPClientComment: function (req, res) {
    // Existing client id and secret
    const body = req.body;
    if (!body.route_id) {
      sails.log(new Date(), "Provide route_id to add comment");
      return res.status(500).send({message: "Provide route_id to add comment"});
    }

    if (!body.comment) {
      return res.status(500).send({message: "Comment is required"});
    }

    return sails.models.auditlog
      .create({
        comment: body.comment,
        route_id: body.route_id
      })
      .then(function (auditlog) {
        if (!auditlog.comment) {
          sails.log(new Date(), "Failed to add log", auditlog);
          return Promise.reject({message: "Failed to add log"});
        }

        return res.send({
          oxd_id: body.oxd_id
        })
      })
      .catch(function (error) {
        return res.status(500).send(error);
      });
  },
});
