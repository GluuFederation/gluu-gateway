(function (factory) {
    if (typeof define === 'function' && define.amd) {
        // AMD. Register as an anonymous module.
        define(['jquery'], factory);
    } else if (typeof module === 'object' && module.exports) {
        // Node/CommonJS
        module.exports = factory(require('jquery'));
    } else {
        // Browser globals
        factory(jQuery);
    }
}(function ($) {
    (function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
        /**
         * StyleFix 1.0.3 & PrefixFree 1.0.7
         * @author Lea Verou
         * MIT license
         */
        (function(){function t(e,t){return[].slice.call((t||document).querySelectorAll(e))}if(!window.addEventListener)return;var e=window.StyleFix={link:function(t){try{if(t.rel!=="stylesheet"||t.hasAttribute("data-noprefix"))return}catch(n){return}var r=t.href||t.getAttribute("data-href"),i=r.replace(/[^\/]+$/,""),s=(/^[a-z]{3,10}:/.exec(i)||[""])[0],o=(/^[a-z]{3,10}:\/\/[^\/]+/.exec(i)||[""])[0],u=/^([^?]*)\??/.exec(r)[1],a=t.parentNode,f=new XMLHttpRequest,l;f.onreadystatechange=function(){f.readyState===4&&l()};l=function(){var n=f.responseText;if(n&&t.parentNode&&(!f.status||f.status<400||f.status>600)){n=e.fix(n,!0,t);if(i){n=n.replace(/url\(\s*?((?:"|')?)(.+?)\1\s*?\)/gi,function(e,t,n){return/^([a-z]{3,10}:|#)/i.test(n)?e:/^\/\//.test(n)?'url("'+s+n+'")':/^\//.test(n)?'url("'+o+n+'")':/^\?/.test(n)?'url("'+u+n+'")':'url("'+i+n+'")'});var r=i.replace(/([\\\^\$*+[\]?{}.=!:(|)])/g,"\\$1");n=n.replace(RegExp("\\b(behavior:\\s*?url\\('?\"?)"+r,"gi"),"$1")}var l=document.createElement("style");l.textContent=n;l.media=t.media;l.disabled=t.disabled;l.setAttribute("data-href",t.getAttribute("href"));a.insertBefore(l,t);a.removeChild(t);l.media=t.media}};try{f.open("GET",r);f.send(null)}catch(n){if(typeof XDomainRequest!="undefined"){f=new XDomainRequest;f.onerror=f.onprogress=function(){};f.onload=l;f.open("GET",r);f.send(null)}}t.setAttribute("data-inprogress","")},styleElement:function(t){if(t.hasAttribute("data-noprefix"))return;var n=t.disabled;t.textContent=e.fix(t.textContent,!0,t);t.disabled=n},styleAttribute:function(t){var n=t.getAttribute("style");n=e.fix(n,!1,t);t.setAttribute("style",n)},process:function(){t('link[rel="stylesheet"]:not([data-inprogress])').forEach(StyleFix.link);t("style").forEach(StyleFix.styleElement);t("[style]").forEach(StyleFix.styleAttribute)},register:function(t,n){(e.fixers=e.fixers||[]).splice(n===undefined?e.fixers.length:n,0,t)},fix:function(t,n,r){for(var i=0;i<e.fixers.length;i++)t=e.fixers[i](t,n,r)||t;return t},camelCase:function(e){return e.replace(/-([a-z])/g,function(e,t){return t.toUpperCase()}).replace("-","")},deCamelCase:function(e){return e.replace(/[A-Z]/g,function(e){return"-"+e.toLowerCase()})}};(function(){setTimeout(function(){t('link[rel="stylesheet"]').forEach(StyleFix.link)},10);document.addEventListener("DOMContentLoaded",StyleFix.process,!1)})()})();(function(e){function t(e,t,r,i,s){e=n[e];if(e.length){var o=RegExp(t+"("+e.join("|")+")"+r,"gi");s=s.replace(o,i)}return s}if(!window.StyleFix||!window.getComputedStyle)return;var n=window.PrefixFree={prefixCSS:function(e,r,i){var s=n.prefix;n.functions.indexOf("linear-gradient")>-1&&(e=e.replace(/(\s|:|,)(repeating-)?linear-gradient\(\s*(-?\d*\.?\d*)deg/ig,function(e,t,n,r){return t+(n||"")+"linear-gradient("+(90-r)+"deg"}));e=t("functions","(\\s|:|,)","\\s*\\(","$1"+s+"$2(",e);e=t("keywords","(\\s|:)","(\\s|;|\\}|$)","$1"+s+"$2$3",e);e=t("properties","(^|\\{|\\s|;)","\\s*:","$1"+s+"$2:",e);if(n.properties.length){var o=RegExp("\\b("+n.properties.join("|")+")(?!:)","gi");e=t("valueProperties","\\b",":(.+?);",function(e){return e.replace(o,s+"$1")},e)}if(r){e=t("selectors","","\\b",n.prefixSelector,e);e=t("atrules","@","\\b","@"+s+"$1",e)}e=e.replace(RegExp("-"+s,"g"),"-");e=e.replace(/-\*-(?=[a-z]+)/gi,n.prefix);return e},property:function(e){return(n.properties.indexOf(e)>=0?n.prefix:"")+e},value:function(e,r){e=t("functions","(^|\\s|,)","\\s*\\(","$1"+n.prefix+"$2(",e);e=t("keywords","(^|\\s)","(\\s|$)","$1"+n.prefix+"$2$3",e);n.valueProperties.indexOf(r)>=0&&(e=t("properties","(^|\\s|,)","($|\\s|,)","$1"+n.prefix+"$2$3",e));return e},prefixSelector:function(e){return e.replace(/^:{1,2}/,function(e){return e+n.prefix})},prefixProperty:function(e,t){var r=n.prefix+e;return t?StyleFix.camelCase(r):r}};(function(){var e={},t=[],r={},i=getComputedStyle(document.documentElement,null),s=document.createElement("div").style,o=function(n){if(n.charAt(0)==="-"){t.push(n);var r=n.split("-"),i=r[1];e[i]=++e[i]||1;while(r.length>3){r.pop();var s=r.join("-");u(s)&&t.indexOf(s)===-1&&t.push(s)}}},u=function(e){return StyleFix.camelCase(e)in s};if(i.length>0)for(var a=0;a<i.length;a++)o(i[a]);else for(var f in i)o(StyleFix.deCamelCase(f));var l={uses:0};for(var c in e){var h=e[c];l.uses<h&&(l={prefix:c,uses:h})}n.prefix="-"+l.prefix+"-";n.Prefix=StyleFix.camelCase(n.prefix);n.properties=[];for(var a=0;a<t.length;a++){var f=t[a];if(f.indexOf(n.prefix)===0){var p=f.slice(n.prefix.length);u(p)||n.properties.push(p)}}n.Prefix=="Ms"&&!("transform"in s)&&!("MsTransform"in s)&&"msTransform"in s&&n.properties.push("transform","transform-origin");n.properties.sort()})();(function(){function i(e,t){r[t]="";r[t]=e;return!!r[t]}var e={"linear-gradient":{property:"backgroundImage",params:"red, teal"},calc:{property:"width",params:"1px + 5%"},element:{property:"backgroundImage",params:"#foo"},"cross-fade":{property:"backgroundImage",params:"url(a.png), url(b.png), 50%"}};e["repeating-linear-gradient"]=e["repeating-radial-gradient"]=e["radial-gradient"]=e["linear-gradient"];var t={initial:"color","zoom-in":"cursor","zoom-out":"cursor",box:"display",flexbox:"display","inline-flexbox":"display",flex:"display","inline-flex":"display",grid:"display","inline-grid":"display","min-content":"width"};n.functions=[];n.keywords=[];var r=document.createElement("div").style;for(var s in e){var o=e[s],u=o.property,a=s+"("+o.params+")";!i(a,u)&&i(n.prefix+a,u)&&n.functions.push(s)}for(var f in t){var u=t[f];!i(f,u)&&i(n.prefix+f,u)&&n.keywords.push(f)}})();(function(){function s(e){i.textContent=e+"{}";return!!i.sheet.cssRules.length}var t={":read-only":null,":read-write":null,":any-link":null,"::selection":null},r={keyframes:"name",viewport:null,document:'regexp(".")'};n.selectors=[];n.atrules=[];var i=e.appendChild(document.createElement("style"));for(var o in t){var u=o+(t[o]?"("+t[o]+")":"");!s(u)&&s(n.prefixSelector(u))&&n.selectors.push(o)}for(var a in r){var u=a+" "+(r[a]||"");!s("@"+u)&&s("@"+n.prefix+u)&&n.atrules.push(a)}e.removeChild(i)})();n.valueProperties=["transition","transition-property"];e.className+=" "+n.prefix;StyleFix.register(n.prefixCSS)})(document.documentElement);

        (function(){var e=!1,n="animation",t=prefix="",i=["Webkit","Moz","O","ms","Khtml"];$(window).on('load',function(){var a=document.body.style;if(void 0!==a.animationName&&(e=!0),e===!1)for(var r=0;r<i.length;r++)if(void 0!==a[i[r]+"AnimationName"]){prefix=i[r],n=prefix+"Animation",t="-"+prefix.toLowerCase()+"-",e=!0;break}});var a=function(e){return $("<style>").attr({"class":"keyframe-style",id:e,type:"text/css"}).appendTo("head")};$.keyframe={getVendorPrefix:function(){return t},isSupported:function(){return e},generate:function(e){var i=e.name||"",r="@"+t+"keyframes "+i+" {";for(var o in e)if("name"!==o){r+=o+" {";for(var f in e[o])r+=f+":"+e[o][f]+";";r+="}"}r=PrefixFree.prefixCSS(r+"}");var s=$("style#"+e.name);if(s.length>0){s.html(r);var m=$("*").filter(function(){this.style[n+"Name"]===i});m.each(function(){var e,n;e=$(this),n=e.data("keyframeOptions"),e.resetKeyframe(function(){e.playKeyframe(n)})})}else a(i).append(r)},define:function(e){if(e.length)for(var n=0;n<e.length;n++){var t=e[n];this.generate(t)}else this.generate(e)}};var r="animation-play-state",o="running";$.fn.resetKeyframe=function(e){$(this).css(t+r,o).css(t+"animation","none");e&&setTimeout(e,1)},$.fn.pauseKeyframe=function(){$(this).css(t+r,"paused")},$.fn.resumeKeyframe=function(){$(this).css(t+r,o)},$.fn.playKeyframe=function(e,n){var i=function(e){return e=$.extend({duration:"0s",timingFunction:"ease",delay:"0s",iterationCount:1,direction:"normal",fillMode:"forwards"},e),[e.name,e.duration,e.timingFunction,e.delay,e.iterationCount,e.direction,e.fillMode].join(" ")},a="";if($.isArray(e)){for(var f=[],s=0;s<e.length;s++)f.push("string"==typeof e[s]?e[s]:i(e[s]));a=f.join(", ")}else a="string"==typeof e?e:i(e);var m=t+"animation",u=["webkit","moz","MS","o",""],c=function(e,n,t){for(var i=0;i<u.length;i++){u[i]||(n=n.toLowerCase());var a=u[i]+n;e.off(a).on(a,t)}};return this.each(function(i,f){var s=$(f).addClass("boostKeyframe").css(t+r,o).css(m,a).data("keyframeOptions",e);n&&(c(s,"AnimationIteration",n),c(s,"AnimationEnd",n))}),this},a("boost-keyframe").append(" .boostKeyframe{"+t+"transform:scale3d(1,1,1);}")}).call(this);

    },{}],2:[function(require,module,exports){
        /**
         * Material Spinner @ 0.0.9
         * @author Lei Lei
         * MIT License
         */

        'use strict';

        var _createClass = (function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ('value' in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; })();

        function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { 'default': obj }; }

        function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError('Cannot call a class as a function'); } }

        var _jquerykeyframes = require('jquerykeyframes');

        var _jquerykeyframes2 = _interopRequireDefault(_jquerykeyframes);

        var Spinner = (function () {
            function Spinner(element, options) {
                _classCallCheck(this, Spinner);

                var time = Date.now();
                this.options = options;
                this.$element = $(element);

                this.realRadius = this.options.radius - this.options.strokeWidth;

                this.rotateName = 'spin-rotate-' + time;
                this.dashName = 'spin-dash-' + time;

                this.defineKeyframes();
                this.createSvg();
            }

            _createClass(Spinner, [{
                key: 'defineKeyframes',
                value: function defineKeyframes() {
                    var dashSpace = this.options.radius * 8;
                    var dashLength = [1, (this.realRadius * 4.7).toFixed(1), (this.realRadius * 4.7).toFixed(1)];
                    var dashOffset = ['0', (0 - this.realRadius * 1.75).toFixed(1), (0 - this.realRadius * 6.23).toFixed(1)];
                    $.keyframe.define([{
                        name: this.rotateName,
                        from: {
                            'transform': 'rotate(0deg)'
                        },
                        to: {
                            'transform': 'rotate(360deg)'
                        }
                    }, {
                        name: this.dashName,
                        '0%': {
                            'stroke-dasharray': dashLength[0] + ',' + dashSpace,
                            'stroke-dashoffset': dashOffset[0]
                        },
                        '50%': {
                            'stroke-dasharray': dashLength[1] + ',' + dashSpace,
                            'stroke-dashoffset': dashOffset[1]
                        },
                        '100%': {
                            'stroke-dasharray': dashLength[2] + ',' + dashSpace,
                            'stroke-dashoffset': dashOffset[2]
                        }
                    }]);
                }
            }, {
                key: 'createSvg',
                value: function createSvg() {
                    var _options = this.options;
                    var radius = _options.radius;
                    var strokeWidth = _options.strokeWidth;

                    var dashSpace = this.options.radius * 8;
                    this.$element.append(this.makeSvg('svg', {
                        width: radius * 2,
                        height: radius * 2
                    }));
                    var $svg = this.$element.find('svg');
                    $svg.append(this.makeSvg('circle', {
                        cx: radius,
                        cy: radius,
                        r: this.realRadius,
                        fill: 'none',
                        'stroke-width': strokeWidth
                    }));
                    var $circle = $svg.find('circle').css({
                        'stroke-dasharray': '1,' + dashSpace,
                        'stroke-dashoffset': '0',
                        'stroke-linecap': 'round',
                        'stroke': this.options.color
                    });
                    $svg.playKeyframe(this.rotateName + ' ' + this.options.duration + 's linear infinite');
                    var circleDuration = this.options.duration / 4.0 * 3.0;
                    $circle.playKeyframe(this.dashName + ' ' + circleDuration.toFixed(1) + 's ease-in-out infinite');
                }
            }, {
                key: 'makeSvg',
                value: function makeSvg(tag, attrs) {
                    var el = document.createElementNS('http://www.w3.org/2000/svg', tag);
                    for (var k in attrs) {
                        el.setAttribute(k, attrs[k]);
                    }
                    return el;
                }
            }]);

            return Spinner;
        })();

        Spinner.VERSION = '0.0.1';

        Spinner.DEFAULTS = {
            radius: 25,
            strokeWidth: 5,
            duration: 2,
            color: '#3f88f8'
        };

        function Plugin(option) {
            var _this = this;

            return this.each(function () {
                var $this = $(_this);
                var options = $.extend({}, Spinner.DEFAULTS, option);

                if (!$this.data('spinnerHandler')) {
                    $this.data('spinnerHandler', new Spinner(_this, options));
                }
            });
        }

        $.fn.spinner = Plugin;
        $.fn.spinner.Constructor = Spinner;

        // Register data api
        $(window).on('load', function () {
            $('[data-spinner]').each(function () {
                var $this = $(this);
                var option = $this.data('spinner');
                if (!$this.data('spinnerHandler')) {
                    Plugin.call($this, option, this);
                }
            });
        });

    },{"jquerykeyframes":1}]},{},[2]);

}));