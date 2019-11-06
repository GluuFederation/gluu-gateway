/**
 * This file contains all necessary Angular controller definitions for 'frontend.admin.login-history' module.
 *
 * Note that this file should only contain controllers and nothing else.
 */
(function () {
  'use strict';

  angular.module('frontend.plugins')
    .service('PluginsService', [
      '$log', '$state', '$http', 'BackendConfig',
      function ($log, $state, $http, BackendConfig) {

        return {

          load: function (query) {
            return $http.get('kong/plugins', {
              params: query
            })
          },

          getPluginsByContext: function (context, service_id) {
            return $http.get('kong/' + context + '/' + service_id + '/plugins')
          },

          add: function (data) {
            return $http.post('kong/plugins', data)
          },

          update: function (id, data) {
            return $http.patch('kong/plugins/' + id, data)
          },

          fetch: function (pluginId) {
            return $http.get('kong/plugins/' + pluginId)
          },

          schema: function (name) {
            return $http.get('kong/plugins/schema/' + name)
          },

          enabled: function () {
            return $http.get('kong/plugins/enabled');
          },

          delete: function (id) {
            return $http.delete('kong/plugins/' + id)
          },

          getOAuthClient: function (oxd_id) {
            return $http.get('api/clients/oauth/' + oxd_id)
          },

          addOAuthClient: function (data) {
            return $http.post('api/clients/oauth', data)
          },

          addOPClient: function (data) {
            return $http.post('api/clients/op', data)
          },

          registerClientAndResources: function (data) {
            return $http.post('api/clients/uma', data)
          },

          updateResources: function (data) {
            return $http.put('api/clients/uma', data)
          },

          updateOPClient: function (data) {
            return $http.put('api/clients/op', data)
          },

          addOAuthConsumerClient: function (data) {
            return $http.post('api/clients/consumer', data)
          },

          deleteConsumerClient: function (client_id, doWantDeleteClient) {
            return $http.delete('api/clients/consumer/' + client_id + '/' + doWantDeleteClient)
          },

          deleteOAuthClient: function (data) {
            return $http.post('api/clients/oauth/delete', data)
          },

          deletePEPClient: function (oxd_id, doWantDeleteClient) {
            return $http.delete('api/clients/uma/' + oxd_id + '/' + doWantDeleteClient)
          },

          getOPDiscoveryResponse: function (data) {
            return $http.post('api/op_discovery', data)
          },

          deleteOPClient: function (data) {
            return $http.post('api/clients/op/delete', data)
          },
        }
      }
    ]);
}());
