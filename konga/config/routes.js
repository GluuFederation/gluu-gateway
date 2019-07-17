'use strict';

/**
 * Route Mappings
 * (sails.config.routes)
 *
 * Your routes map URLs to views and controllers.
 *
 * If Sails receives a URL that doesn't match any of the routes below,
 * it will check for matching files (images, scripts, stylesheets, etc.)
 * in your assets directory.  e.g. `http://localhost:1337/images/foo.jpg`
 * might match an image file: `/assets/images/foo.jpg`
 *
 * Finally, if those don't match either, the default 404 handler is triggered.
 * See `config/404.js` to adjust your app's 404 logic.
 *
 * Note: Sails doesn't ACTUALLY serve stuff from `assets`-- the default Gruntfile in Sails copies
 * flat files from `assets` to `.tmp/public`.  This allows you to do things like compile LESS or
 * CoffeeScript for the front-end.
 *
 * For more information on configuring custom routes, check out:
 * http://sailsjs.org/#/documentation/concepts/Routes/RouteTargetSyntax.html
 */

module.exports.routes = {
  // See https://github.com/balderdashy/sails/issues/2062
  'OPTIONS /*': function (req, res) {
    res.send(200);
  },

  '/': function (req, res) {

    return res.view('homepage', {
      angularDebugEnabled: process.env.NODE_ENV == 'production' ? false : true,
      konga_version: sails.config.ggVersion,
      postgres_version: sails.config.postgresVersion,
      accountActivated: req.query.activated ? true : false
    })
  },


  '/404': {
    view: '404'
  },

  '/500': {
    view: '500'
  },

  // Authentication routes
  '/logout': 'AuthController.logout',
  'POST /login': 'AuthController.callback',
  'POST /login/:action': 'AuthController.callback',
  'POST /auth/local': 'AuthController.callback',
  'POST /auth/local/:action': 'AuthController.callback',
  'POST /auth/signup': 'AuthController.signup',
  'GET /auth/activate/:token': 'AuthController.activate',
  '/auth/:provider': 'AuthController.provider',
  '/auth/:provider/callback': 'AuthController.callback',
  '/auth/:provider/:action': 'AuthController.callback',

  //'POST /consumers/sync'                 : 'ConsumerController.sync',


  // Remote Storage routes
  'GET /remote/adapters': 'RemoteStorageController.loadAdapters',
  'POST /remote/consumers': 'RemoteStorageController.loadConsumers',
  'GET /remote/connection/test': 'RemoteStorageController.testConnection',

  // Snapshots
  'POST /api/snapshots/take': 'SnapshotController.takeSnapShot',
  'GET /api/snapshots/subscribe': 'SnapshotController.subscribe',
  'POST /api/snapshots/:id/restore': 'SnapshotController.restore',
  'GET /api/snapshots/:id/download': 'SnapshotController.download',

  // Socket Subscriptions
  'GET /api/kongnodes/healthchecks/subscribe': 'KongNodeController.subscribeHealthChecks',
  'GET /api/apis/healthchecks/subscribe': 'ApiHealthCheckController.subscribeHealthChecks',
  'GET /api/user/:id/subscribe': 'UserController.subscribe',

  // Rich Plugins List
  'GET /api/kong_plugins/list': 'KongPluginsController.list',
  'GET /api/schemas/authentication': 'KongSchemasController.authentication',

  // Consumer portal
  'GET /api/kong_consumers/:id/apis': 'KongConsumersController.apis',
  'GET /api/kong_consumers/:id/services': 'KongConsumersController.services',
  'GET /api/kong_consumers/:id/routes': 'KongConsumersController.routes',

  'GET /api/kong_services/:id/consumers': 'KongServicesController.consumers',
  'GET /api/kong_routes/:id/consumers': 'KongRoutesController.consumers',

  'GET /api/settings': 'SettingsController.find',

  // Client controller
  'POST /api/op_discovery': 'ClientsController.opDiscovery',
  'POST /api/clients/oauth': 'ClientsController.addGluuClientAuth',
  'POST /api/clients/uma': 'ClientsController.addGluuUMAPEP',
  'POST /api/clients/op': 'ClientsController.addOPClient',
  'PUT /api/clients/uma': 'ClientsController.updateGluuUMAPEP',
  'PUT /api/clients/op': 'ClientsController.updateOPClient',
  'POST /api/clients/consumer': 'ClientsController.addConsumerClient',
  'POST /api/clients/oauth/delete': 'ClientsController.deleteGluuClientAuth',
  'POST /api/clients/op/delete': 'ClientsController.deleteOPClientComment',

  /**
   * Fallback to proxy
   */

  'GET /kong': 'KongProxyController.proxy',
  'GET /kong/*': 'KongProxyController.proxy',
  'POST /kong/*': 'KongProxyController.proxy',
  'PUT /kong/*': 'KongProxyController.proxy',
  'PATCH /kong/*': 'KongProxyController.proxy',
  'DELETE /kong/*': 'KongProxyController.proxy'
};
