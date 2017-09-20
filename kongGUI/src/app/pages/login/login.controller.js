(function () {
  'use strict';

  angular.module('KongGUI.pages.login')
    .controller('LoginController', LoginController);

  /** @ngInject */
  function LoginController($http, $localStorage, $window, $location, loginService, toastr, urls) {
    var vm = this;
    vm.login = login;
    vm.logout = logout;
    vm.params = $location.search();

    if (vm.params && vm.params.code && $localStorage.authDetail) {
      if (vm.params.error) {
        toastr.error(vm.params.error_description, 'Sign In', {});
      } else {
        $localStorage.authDetail.code = vm.params.code;
        $localStorage.authDetail.state = vm.params.state;
        loginService.login($localStorage.authDetail, onSuccess, onError);
      }
      delete $localStorage.authDetail;
    }

    function onSuccess(response) {
      debugger;
      // login successful if there's a token in the response
      if (response.token) {
        // store username and token in local storage to keep user logged in between page refreshes
        $localStorage.currentUser = {user: response.user, role: response.role, token: response.token};
        $window.location = urls.BASE;
      } else {
        // execute callback with false to indicate failed login
        toastr.error(response.info.message, 'Login failed.', {})
      }

      return true;
    }

    function onError(error) {
      toastr.error(error.data.message, 'OXD-KONG');

      return true;
    }

    function login() {
      loginService.getAuthorizeURL(onSuccess, onError);

      function onSuccess(response) {
        if (response) {
          $localStorage.authDetail = response.data;
          $window.location = response.data.authURL;
          event.preventDefault();
        }
      }

      function onError(error) {
        toastr.error(error.data.message, 'OXD-KONG');
      }
    }

    function logout() {
      // remove user from local storage and clear http auth header
      delete $localStorage.currentUser;
      $http.defaults.headers.common.Authorization = '';
      $window.location = urls.AUTH_URL;
    }
  }
})();
