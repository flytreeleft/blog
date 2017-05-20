/* eslint-disable */
(function ($) {
    "use strict";

    $('.article-footer-donate .icon-like').click(function () {
        var $parent = $(this).parent();
        var $qrCodes = $('.qr-codes', $parent);

        $qrCodes.toggle();
    });

})(jQuery);