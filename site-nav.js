// Menu button for the shared site nav on small screens.
// Without this script the full link list simply shows on every screen size.
(function () {
    var nav = document.querySelector('.site-nav');
    if (!nav) return;
    var toggle = nav.querySelector('.site-nav-toggle');
    if (!toggle) return;

    nav.classList.add('js');

    toggle.addEventListener('click', function () {
        var open = nav.classList.toggle('open');
        toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
})();
