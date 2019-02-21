/**
 * Messages component which is divided to following logical components:
 *
 *  Controllers
 *
 * All of these are wrapped to 'frontend.auth.login' angular module.
 */
(function () {
  'use strict';

  // Define frontend.auth.login angular module
  angular.module('frontend.core.auth.login', []);

  // Module configuration
  angular.module('frontend.core.auth.login')
    .config([
      '$stateProvider',
      function config($stateProvider) {
        $stateProvider
        // Login
          .state('auth.login', {
            url: '/login?activated',
            data: {
              access: 0
            },
            params: {
              activated: null
            },
            views: {
              'authContent': {
                templateUrl: 'js/app/core/auth/login/login.html',
                controller: 'LoginController'
              },

            }
          })
        ;
      }
    ])
    .controller('LoginController', [
      '$scope', '$state', '$stateParams',
      'AuthService', 'FocusOnService', 'MessageService', '$localStorage',
      function controller($scope, $state, $stateParams,
                          AuthService, FocusOnService, MessageService, $localStorage) {
        $scope.login = login;

        function getParameterByName(name, url) {
          if (!url) url = window.location.href;
          name = name.replace(/[\[\]]/g, "\\$&");
          var regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)"),
            results = regex.exec(url);
          if (!results) return null;
          if (!results[2]) return '';
          return decodeURIComponent(results[2].replace(/\+/g, " "));
        }

        if (!!getParameterByName("code") && !!getParameterByName("state")) {
          $scope.busy = true;
          AuthService
            .login({code: getParameterByName("code"), state: getParameterByName("state")})
            .then(
              function (response) {
                MessageService.success('You have logged in successfully!');
                $localStorage.credentials = response.data;
                window.location = window.location.origin + '#!/dashboard'
                $scope.busy = false;
              })
            .catch(function errorCallback(err) {
              MessageService.error(err.data.message || err.data.error.message);
              $scope.busy = false;
            });

          return;
        }

        // Scope function to perform actual login request to server
        function login() {
          $scope.busy = true;
          AuthService
            .login({})
            .then(function successCallback(response) {
              window.location = response.data.authURL;
            })
            .catch(function errorCallback(err) {
              MessageService.error(err.data.message || 'OXD Error: Check oxd server log: ' + err.data.error.error_description);
              $scope.busy = false;
            });
        };

        /**
         * Private helper function to reset credentials and set focus to username input.
         *
         * @private
         */
        function _reset() {
          FocusOnService.focus('username');

          // Initialize credentials
          $scope.credentials = {
            identifier: '',
            password: ''
          };
        }

        _reset();
      }
    ])
  ;
}());
