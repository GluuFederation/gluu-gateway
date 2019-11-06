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
          redirect_uris: clientRequest.redirect_uris || ['https://client.example.com/cb'],
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
        sails.log(new Date(), error);
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

        return res.status(200).send({
          oxd_id: opClient.oxd_id,
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
      client_name: body.client_name || 'gg-oauth-consumer-client',
      client_id: body.client_id || '',
      client_secret: body.client_secret || '',
      access_token_as_jwt: body.access_token_as_jwt || false,
      rpt_as_jwt: body.rpt_as_jwt || false,
      access_token_signing_alg: body.access_token_signing_alg || 'RS256',
      scope: body.scope
    };

    this.registerClient(option)
      .then(function (clientInfo) {
        opClient = clientInfo;
        if (!clientInfo.client_id && !clientInfo.client_secret && !clientInfo.oxd_id) {
          sails.log(new Date(), "Failed to register client", clientInfo);
          return Promise.reject({message: "Failed to register client"});
        }

        return res.status(200).send({
          oxd_id: opClient.oxd_id,
          client_id: opClient.client_id,
          client_secret: opClient.client_secret
        });
      })
      .catch(function (error) {
        sails.log(new Date(), '--- addConsumerClient ---', error);
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

    // Create new client
    const reqBody = {
      op_host: body.op_host,
      oxd_url: body.oxd_url,
      redirect_uris: body.redirect_uris || ['https://client.example.com/cb'],
      client_name: body.client_name || 'gg-openid-connect-client',
      post_logout_redirect_uris: body.post_logout_redirect_uris || [],
      scope: body.scope,
      acr_values: body.acr_values || [],
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

    sails.log(new Date(), "--------------OXD API Call----------------");
    sails.log(new Date(), ` $ curl -k -X POST ${body.oxd_url + '/register-site'} -d '${JSON.stringify(option.body)}'`);

    var opClient;
    return httpRequest(option)
      .then(function (response) {
        opClient = response.body;
        if (!opClient.client_id && !opClient.client_secret && !opClient.oxd_id) {
          sails.log(new Date(), "Failed to register client", opClient);
          return Promise.reject({message: "Failed to register client"});
        }

        if (!(body.uma_scope_expression && body.uma_scope_expression.length > 0)) {
          return Promise.resolve(response)
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

        return httpRequest(option)
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
          });
      })
      .then(function (response) {
        var result = response.body;
        if (!result.oxd_id) {
          sails.log(new Date(), "Failed to update resources", response);
          return Promise.reject({message: "Failed to update resources"});
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
          oxd_id: opClient.oxd_id,
          client_id: opClient.client_id,
          client_secret: opClient.client_secret
        })
      })
      .catch(function (error) {
        sails.log(new Date(), error);
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
    var clientATToken;
    return httpRequest(option)
      .then(function (response) {
        var clientToken = response.body;
        clientATToken = clientToken.access_token;

        // Create new client
        const reqBody = {
          oxd_id: body.oxd_id,
          op_host: body.op_host,
          oxd_url: body.oxd_url,
          redirect_uris: body.redirect_uris || ['https://client.example.com/cb'],
          post_logout_redirect_uris: body.post_logout_redirect_uris,
          scope: body.scope,
          acr_values: body.acr_values || [],
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
        if (!(body.uma_scope_expression && body.uma_scope_expression.length > 0)) {
          return Promise.resolve(response)
        }

        var reqBody = {};
        if (body.alreadyAddedUMAExpression) {
          reqBody = {
            oxd_id: body.oxd_id,
            resources: body.uma_scope_expression,
            overwrite: true
          }
        } else {
          reqBody = {
            oxd_id: body.oxd_id,
            resources: body.uma_scope_expression
          }
        }

        var option = {
          method: 'POST',
          uri: body.oxd_url + '/uma-rs-protect',
          body: reqBody,
          headers: {
            Authorization: 'Bearer ' + clientATToken
          },
          resolveWithFullResponse: true,
          json: true
        };

        sails.log(new Date(), "--------------OXD API Call----------------");
        sails.log(new Date(), ` $ curl -k -X POST ${body.oxd_url + '/uma-rs-protect'} -H 'Authorization: Bearer ${clientATToken}' -d '${JSON.stringify(option.body)}'`);

        return httpRequest(option)
          .catch(function(e){
            if (e.error && e.error.error === "uma_protection_exists") {
              option.body.overwrite = true;
              return httpRequest(option)
            }

            return Promise.reject({message: "Failed to register client"});
          });
      })
      .then(function (response) {
        var result = response.body;
        if (!result.oxd_id) {
          sails.log(new Date(), "Failed to update resources or update site", result);
          return Promise.reject({message: "Failed to update resources"});
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
        sails.log(new Date(), error);
        return res.status(500).send(error);
      });
  },
});
