(function() {
    'use strict';

    /**
     * Model for Author API, this is used to wrap all Author objects specified actions and data change actions.
     */
    angular.module('frontend.logs')
        .service('LogModel', [
            'DataModel',
            function(DataModel) {
                var model = new DataModel('auditlog');
                return model;
            }
        ]);
}());
