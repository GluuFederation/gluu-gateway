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
  registerClient: function (clientRequest) {
    return new Promise(function (resolve, reject) {
      // Create new client
      const option = {
        method: 'POST',
        uri: sails.config.oxdWeb + '/register-site',
        body: {
          op_host: sails.config.opHost,
          authorization_redirect_uri: clientRequest.authorization_redirect_uri || 'https://client.example.com/cb',
          client_name: clientRequest.client_name || 'gg-client',
          client_id: clientRequest.client_id || '',
          client_secret: clientRequest.client_secret || '',
          scope: clientRequest.scope || ['openid', 'oxd'],
          grant_types: clientRequest.grant_types || ['client_credentials'],
          access_token_as_jwt: clientRequest.access_token_as_jwt || false
        },
        resolveWithFullResponse: true,
        json: true
      };

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
          console.log('----- Error Client registration -----', error);
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
          console.log("Failed to fetch client data");
          return res.status(500).send("Failed to fetch client data");
        }

        return res.status(200).send(oClient);
      })
      .catch(function (error) {
        console.log(error);
        return res.status(500).send("Failed to fetch client data");
      });
  },

  // User to register client for OAuth plugin
  addGluuClientAuth: function (req, res) {
    // Existing client id and secret
    if (req.body.oxd_id && req.body.client_id && req.body.client_secret) {
      return res.send({oxd_id: req.body.oxd_id, client_id: req.body.client_id, client_secret: req.body.client_secret})
    }

    // Create new client
    const option = {
      op_host: sails.config.opHost,
      authorization_redirect_uri: 'https://client.example.com/cb',
      client_name: req.body.client_name || 'gg-oauth-client',
      client_id: req.body.client_id || '',
      client_secret: req.body.client_secret || ''
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
    // Existing client id and secret
    if (!req.body.uma_scope_expression) {
      return res.status(400).send({message: "uma_scope_expression is required"});
    }
    var opClient;
    var that = this;
    new Promise(function (resolve, reject) {
      if (req.body.oxd_id && req.body.client_id && req.body.client_secret) {
        return resolve({
          oxd_id: req.body.oxd_id,
          client_id: req.body.client_id,
          client_secret: req.body.client_secret
        })
      } else {
        const option = {
          op_host: sails.config.opHost,
          authorization_redirect_uri: 'https://client.example.com/cb',
          client_name: req.body.client_name || 'gg-uma-client',
          client_id: req.body.client_id || '',
          client_secret: req.body.client_secret || '',
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
          console.log("Failed to register client", clientInfo);
          return Promise.reject({message: "Failed to register client"});
        }

        var option = {
          method: 'POST',
          uri: sails.config.oxdWeb + '/get-client-token',
          body: {
            op_host: sails.config.opHost,
            client_id: opClient.client_id,
            client_secret: opClient.client_secret,
            scope: ['openid', 'oxd']
          },
          resolveWithFullResponse: true,
          json: true
        };

        return httpRequest(option);
      })
      .then(function (response) {
        var clientToken = response.body;
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
        var umaProtect = response.body;
        if (!umaProtect.oxd_id) {
          console.log("Failed to register resources", response);
          return Promise.reject({message: "Failed to register resources"});
        }

        return sails.models.client
          .create({
            oxd_id: umaProtect.oxd_id,
            client_id: opClient.client_id,
            client_secret: opClient.client_secret,
            context: 'GLUU-UMA-PEP',
            data: req.body.uma_scope_expression
          })
      })
      .then(function (dbClient) {
        if (!dbClient.oxd_id) {
          console.log("Failed to add client and resources in konga db", dbClient);
          return Promise.reject({message: "Failed to add client and resources in konga db"});
        }

        return res.status(200).send({
          oxd_id: dbClient.oxd_id,
          client_id: opClient.client_id,
          client_secret: opClient.client_secret
        });
      })
      .catch(function (error) {
        console.log('---- registerClientAndResources ----', error);
        return res.status(500).send(error);
      });
  },

  // add client for consumer
  addConsumerClient: function (req, res) {
    var opClient;
    // Create new client
    const option = {
      op_host: sails.config.opHost,
      authorization_redirect_uri: 'https://client.example.com/cb',
      client_name: req.body.client_name || 'gg-oauth-consumer-client',
      client_id: req.body.client_id || '',
      client_secret: req.body.client_secret || '',
      access_token_as_jwt: req.body.access_token_as_jwt || false
    };

    this.registerClient(option)
      .then(function (clientInfo) {
        opClient = clientInfo;
        if (!clientInfo.client_id && !clientInfo.client_secret && !clientInfo.oxd_id) {
          console.log("Failed to register client", clientInfo);
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
          console.log("Failed to add client and resources in konga db", dbClient);
          return Promise.reject({message: "Failed to add client and resources in konga db"});
        }

        return res.status(200).send({
          oxd_id: dbClient.oxd_id,
          client_id: opClient.client_id,
          client_secret: opClient.client_secret
        });
      })
      .catch(function (error) {
        console.log('--- addOAuthConsumerClient ---', error);
        return res.status(500).send(error);
      });
  },

  // Update UMA resources
  updateGluuUMAPEP: function (req, res) {
    // Existing client id and secret
    if (!req.body.uma_scope_expression) {
      return res.status(400).send({message: "uma_scope_expression is required"});
    }

    if (!req.body.oxd_id) {
      console.log("Provide oxd_id to update resources");
      return res.status(500).send({message: "Provide oxd_id to update resources"});
    }

    if (!req.body.client_id) {
      console.log("Provide client_id to update resources");
      return res.status(500).send({message: "Provide client_id to update resources"});
    }

    if (!req.body.client_secret) {
      console.log("Provide oxd_id to update resources");
      return res.status(500).send({message: "Provide client_secret to update resources"});
    }

    var option = {
      method: 'POST',
      uri: sails.config.oxdWeb + '/get-client-token',
      body: {
        op_host: sails.config.opHost,
        client_id: req.body.client_id,
        client_secret: req.body.client_secret,
        scope: ['openid', 'oxd']
      },
      resolveWithFullResponse: true,
      json: true
    };

    return httpRequest(option)
      .then(function (response) {
        var clientToken = response.body;
        var option = {
          method: 'POST',
          uri: sails.config.oxdWeb + '/uma-rs-protect',
          body: {
            oxd_id: req.body.oxd_id,
            resources: req.body.uma_scope_expression,
            overwrite: true,
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
        var umaProtect = response.body;
        if (!umaProtect.oxd_id) {
          console.log("Failed to update resources", response);
          return Promise.reject({message: "Failed to update resources"});
        }

        return sails.models.client
          .update({
            oxd_id: umaProtect.oxd_id
          }, {
            data: req.body.uma_scope_expression
          });
      })
      .then(function (dbClient) {
        if (dbClient.length < 1) {
          console.log("Failed to update client in konga db", dbClient);
          return Promise.reject({message: "Failed to update client in konga db"});
        }
        return res.status(200).send({
          oxd_id: req.body.oxd_id
        });
      })
      .catch(function (error) {
        console.log(error);
        return res.status(500).send(error);
      });
  },

  // delete consumer client
  deleteConsumerClient: function (req, res) {
    var kongaDBClient;
    console.log("doWantDeleteClient: ", req.params.doWantDeleteClient);
    // doWantDeleteClient=true Delete client from GG and OXD
    if (req.params.doWantDeleteClient == "true") {
      return sails.models.client
        .findOne({
          client_id: req.params.client_id
        })
        .then(function (oClient) {
          kongaDBClient = oClient;

          if (!kongaDBClient) {
            console.log("Client does not exists in GG");
            return Promise.reject({message: "Client does not exists in GG"});
          }

          if (kongaDBClient.oxd_id == sails.config.oxdId) {
            console.log("Not allow to delete GG Admin login client");
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

          return httpRequest(option);
        })
        .then(function (response) {
          var deletedClient = response.body;

          if (!deletedClient.oxd_id) {
            console.log('Failed to delete client from OXD', deletedClient);
            return Promise.reject({message: "Failed to delete client from OXD"});
          }

          return sails.models.client
            .destroy({
              oxd_id: deletedClient.oxd_id
            });
        })
        .then(function (deletedClient) {
          if (deletedClient.length <= 0) {
            console.log('Failed to delete client from GG', deletedClient);
            return Promise.reject({message: "Failed to delete client from GG"});
          }

          return res.status(200).send(deletedClient);
        })
        .catch(function (error) {
          console.log(error);
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
              console.log('deleteClient:', deleteClient);
            });
        }
        return res.status(200).send();
      })
      .catch(function (error) {
        console.log(error);
        return res.status(500).send(error);
      });
  },

  // delete client from oxd for client-auth plugin
  deleteGluuClientAuth: function (req, res) {
    if (!req.body.oxd_id) {
      console.log("Provide oxd_id to update resources");
      return res.status(500).send({message: "Provide oxd_id to update resources"});
    }

    if (!req.body.client_id) {
      console.log("Provide client_id to update resources");
      return res.status(500).send({message: "Provide client_id to update resources"});
    }

    if (!req.body.client_secret) {
      console.log("Provide oxd_id to update resources");
      return res.status(500).send({message: "Provide client_secret to update resources"});
    }

    var option = {
      method: 'POST',
      uri: sails.config.oxdWeb + '/get-client-token',
      body: {
        op_host: sails.config.opHost,
        client_id: req.body.client_id,
        client_secret: req.body.client_secret,
        scope: ['openid', 'oxd']
      },
      resolveWithFullResponse: true,
      json: true
    };

    return httpRequest(option)
      .then(function (response) {
        var clientToken = response.body;

        if (req.body.oxd_id == sails.config.oxdId) {
          console.log("Not allow to delete GG Admin login client");
          return Promise.reject({message: "Not allow to delete GG Admin login client"});
        }

        var option = {
          method: 'POST',
          uri: sails.config.oxdWeb + '/remove-site',
          body: {
            oxd_id: req.body.oxd_id
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
        var deletedClient = response.body;

        if (!deletedClient.oxd_id) {
          console.log('Failed to delete client from oxd', deletedClient);
          return Promise.reject({message: 'Failed to delete client from oxd'});
        }

        return res.status(200).send(deletedClient);
      })
      .catch(function (error) {
        console.log(error);
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
            console.log("Client does not exists in GG");
            return Promise.reject({message: "Client does not exists in GG"});
          }

          if (kongaDBClient.oxd_id == sails.config.oxdId) {
            console.log("Not allow to delete GG Admin login client");
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

          return httpRequest(option);
        })
        .then(function (response) {
          var deletedClient = response.body;

          if (!deletedClient.oxd_id) {
            console.log('Failed to delete client from oxd', deletedClient);
            return Promise.reject({message: "Failed to delete client from oxd"});
          }
          return sails.models.client
            .destroy({
              oxd_id: deletedClient.oxd_id
            });
        })
        .then(function (deletedClient) {
          if (deletedClient.length <= 0) {
            console.log('Failed to delete client from GG', deletedClient);
            return Promise.reject({message: "Failed to delete client from GG"});
          }

          return res.status(200).send(deletedClient);
        })
        .catch(function (error) {
          console.log(error);
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
              console.log('deleteClient:', deleteClient);
            });
        }
        return res.status(200).send();
      })
      .catch(function (error) {
        console.log(error);
        return res.status(500).send(error);
      });
  },
});
