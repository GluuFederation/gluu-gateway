'use strict';

var async = require('async');
var _ = require('lodash');
var uuid = require('node-uuid');
var httpRequest = require('request-promise');
var UserSignUp = require("../events/user-events")

/**
 * Authentication Controller
 */
var AuthController = {


  signup: function (req, res) {

    var data = req.allParams()
    var passports = data.passports
    delete data.passports;
    delete data.password_confirmation


    // Assign activation token
    data.activationToken = uuid.v4();

    // Check settings as to what to do after signup
    sails.models.settings
      .find()
      .limit(1)
      .exec(function (err, settings) {
        if (err) return res.negotiate(err)
        var _settings = settings[0].data;

        if (!_settings.signup_require_activation) {
          data.active = true; // Activate user automatically
        }


        sails.models.user
          .create(data)
          .exec(function (err, user) {
            if (err) return res.negotiate(err)

            sails.models.passport
              .create({
                protocol: passports.protocol,
                password: passports.password,
                user: user.id
              }).exec(function (err, passport) {
              if (err) return res.negotiate(err)

              // Emit signUp event
              UserSignUp.emit('user.signUp', {
                user: user,
                sendActivationEmail: _settings.signup_require_activation
              });

              return res.json(user)
            })
          })

      })


  },


  activate: function (req, res) {


    var token = req.param('token')
    if (!token) {
      return res.badRequest('Token is required.')
    }

    sails.models.user.findOne({
      activationToken: token,
      activated: false
    }).exec(function (err, user) {
      if (err) return res.negotiate(err)
      if (!user) return res.notFound('Invalid token')

      sails.models.user.update({
        id: user.id
      }, {active: true})
        .exec(function (err, updated) {
          if (err) return res.negotiate(err)
          return res.redirect('/#!/login?activated=' + req.param('token'))
        })
    })

  },

  /**
   * Log out a user and return them to the homepage
   *
   * Passport exposes a logout() function on request (also aliased as logOut()) that can be
   * called from any route handler which needs to terminate a login session. Invoking logout()
   * will remove the request.user property and clear the login session (if any).
   *
   * For more information on logging out users in Passport.js, check out:
   * http://passportjs.org/guide/logout/
   *
   * @param   {Request}   request     Request object
   * @param   {Response}  response    Response object
   */
  logout: function logout(request, response) {
    request.logout();

    response.json(200, true);
  },

  /**
   * Create a third-party authentication endpoint
   *
   * @param   {Request}   request     Request object
   * @param   {Response}  response    Response object
   */
  provider: function provider(request, response) {
    sails.services.passport.endpoint(request, response);
  },

  /**
   * Simple action to check current auth status of user. Note that this will always send
   * HTTP status 200 and actual data will contain either user object or boolean false in
   * cases that user is not authenticated.
   *
   * @todo    Hmmm, I think that this will return always false, because of missing of
   *          actual sessions here...
   *
   * @param   {Request}   request     Request object
   * @param   {Response}  response    Response object
   */
  authenticated: function authenticated(request, response) {
    if (request.isAuthenticated()) {
      response.json(200, request.user);
    } else {
      response.json(200, false);
    }
  },

  /**
   * Create a authentication callback endpoint
   *
   * This endpoint handles everything related to creating and verifying Passports
   * and users, both locally and from third-party providers.
   *
   * Passport exposes a login() function on request (also aliased as logIn()) that
   * can be used to establish a login session. When the login operation completes,
   * user will be assigned to request.user.
   *
   * For more information on logging in users in Passport.js, check out:
   * http://passportjs.org/guide/login/
   *
   * @param   {Request}   request     Request object
   * @param   {Response}  response    Response object
   */
  callback: function callback(req, res) {
    req.body.identifier = 'admin';
    req.body.password = 'adminadminadmin';
    sails.services.passport.callback(req, res, function callback(error, user) {
      if (!!req.body.code && !!req.body.state) {
        var clientToken = '';
        return getClientAccessToken()
          .then(function (token) {
            clientToken = token;
            const option = {
              method: 'POST',
              headers: {
                Authorization: 'Bearer ' + clientToken
              },
              uri: sails.config.oxdWeb + '/get-tokens-by-code',
              body: {
                oxd_id: sails.config.oxdId,
                code: req.body.code,
                state: req.body.state
              },
              resolveWithFullResponse: true,
              json: true
            };

            return httpRequest(option);
          })
          .then(function (response) {
            const codeToken = response.body;
            const option = {
              method: 'POST',
              headers: {
                Authorization: 'Bearer ' + clientToken
              },
              uri: sails.config.oxdWeb + '/get-user-info',
              body: {
                oxd_id: sails.config.oxdId,
                access_token: codeToken.data.access_token
              },
              resolveWithFullResponse: true,
              json: true
            };

            return httpRequest(option);
          })
          .then(function (response) {
            const userInfo = response.body;

            if (userInfo.status === 'error') {
              return Promise.reject(userInfo.data)
            }
            user.info = userInfo.data;
            return res.send({user: user, token: sails.services.token.issue(_.isObject(user.id) ? JSON.stringify(user.id) : user.id)});
          })
          .catch(function (error) {
            return res.status(500).send({error: error});
          });
      }

      return getClientAccessToken()
        .then(function (token) {
          const option = {
            method: 'POST',
            headers: {
              Authorization: 'Bearer ' + token
            },
            uri: sails.config.oxdWeb + '/get-authorization-url',
            body: {
              oxd_id: sails.config.oxdId,
              scope: ['openid', 'email', 'profile', 'uma_protection', 'permission']
            },
            resolveWithFullResponse: true,
            json: true
          };

          return httpRequest(option);
        })
        .then(function (response) {
          const urlData = response.body;

          if (urlData.status === 'error') {
            return Promise.reject(urlData.data)
          }

          return res.send({authURL: urlData.data.authorization_url});
        })
        .catch(function (error) {
          return res.status(500).send({error: error});
        });

      function getClientAccessToken() {
        var option = {
          method: 'POST',
          uri: sails.config.oxdWeb + '/get-client-token',
          body: {
            client_id: sails.config.clientId,
            client_secret: sails.config.clientSecret,
            scope: ['openid', 'email', 'profile', 'uma_protection'],
            op_host: sails.config.opHost
          },
          resolveWithFullResponse: true,
          json: true
        };

        return httpRequest(option)
          .then(function (response) {
            const tokenData = response.body;

            if (tokenData.status === 'error') {
              return Promise.reject(tokenData.data)
            }

            return Promise.resolve(tokenData.data.access_token);
          })
      }
    });
  },

  /**
   * Action to check if given password is same as current user password. Note that
   * this action is only allowed authenticated users. And by default given password
   * is checked against to current user.
   *
   * @param   {Request}   request     Request object
   * @param   {Response}  response    Response object
   */
  checkPassword: function checkPassword(request, response) {
    /**
     * Job to fetch current user local passport data. This is needed
     * to validate given password.
     *
     * @param {Function}  next  Callback function
     */
    var findPassport = function findPassport(next) {
      var where = {
        user: request.token,
        protocol: 'local'
      };

      sails.models.passport
        .findOne(where)
        .exec(function callback(error, passport) {
          if (error) {
            next(error);
          } else if (!passport) {
            next({message: 'Given authorization token is not valid'});
          } else {
            next(null, passport);
          }
        })
      ;
    };

    /**
     * Job to validate given password against user passport object.
     *
     * @param {sails.model.passport}  passport  Passport object
     * @param {Function}              next      Callback function
     */
    var validatePassword = function validatePassword(passport, next) {
      var password = request.param('password');

      passport.validatePassword(password, function callback(error, matched) {
        if (error) {
          next({message: 'Invalid password'});
        } else {
          next(null, matched);
        }
      });
    };

    /**
     * Main callback function which is called when all specified jobs are
     * processed or an error has occurred while processing.
     *
     * @param   {null|Error}    error   Possible error
     * @param   {null|boolean}  result  If passport was valid or not
     */
    var callback = function callback(error, result) {
      if (error) {
        response.json(401, error);
      } else if (result) {
        response.json(200, result);
      } else {
        response.json(400, {message: 'Given password does not match.'});
      }
    };

    // Run necessary tasks and handle results
    async.waterfall([findPassport, validatePassword], callback);
  }
};

module.exports = AuthController;
