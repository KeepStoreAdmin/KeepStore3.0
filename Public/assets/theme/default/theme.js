(function () {
    "use strict";

    var links = document.querySelectorAll(".ks-theme-test-page a[href='#']");

    for (var i = 0; i < links.length; i += 1) {
        links[i].addEventListener("click", function (event) {
            event.preventDefault();
        });
    }
}());
