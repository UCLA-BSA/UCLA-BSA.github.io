(function () {
  'use strict';

  function buildAccordion() {
    var container = document.querySelector('.quarto-listing-category');
    if (!container) return;

    var allItems = Array.from(container.querySelectorAll('.category'));
    if (!allItems.length) return;

    var groups = { Advisor: [], Cohort: [] };

    allItems.forEach(function (el) {
      var text = el.textContent.trim();
      if (text.startsWith('Advisor: ')) {
        groups.Advisor.push(el);
      } else if (text.startsWith('Cohort: ')) {
        groups.Cohort.push(el);
      } else if (text.startsWith('Program: ')) {
        // Hide program filter — page is already scoped to one program
        el.remove();
      }
    });

    // Remove grouped items from DOM before rebuilding
    groups.Advisor.concat(groups.Cohort).forEach(function (el) {
      el.remove();
    });

    ['Advisor', 'Cohort'].forEach(function (groupName) {
      var items = groups[groupName];
      if (!items.length) return;

      var wrapper = document.createElement('div');
      wrapper.className = 'category-accordion-group';

      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'category-accordion-header';
      btn.setAttribute('aria-expanded', 'false');
      btn.innerHTML =
        '<span class="accordion-label">' + groupName + '</span>' +
        '<span class="accordion-arrow">&#8250;</span>';

      var list = document.createElement('div');
      list.className = 'category-accordion-items';
      list.style.display = 'none';

      items.forEach(function (el) {
        // Strip the "Advisor: " / "Cohort: " prefix for a cleaner label
        var full = el.textContent.trim();
        var label = full.replace(groupName + ': ', '');
        el.textContent = label;
        list.appendChild(el);
      });

      btn.addEventListener('click', function () {
        var expanded = btn.getAttribute('aria-expanded') === 'true';
        btn.setAttribute('aria-expanded', String(!expanded));
        list.style.display = expanded ? 'none' : 'block';
        btn.querySelector('.accordion-arrow').classList.toggle('open', !expanded);
      });

      wrapper.appendChild(btn);
      wrapper.appendChild(list);
      container.appendChild(wrapper);
    });
  }

  // Run after Quarto's listing JS has initialised
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', buildAccordion);
  } else {
    setTimeout(buildAccordion, 0);
  }
})();
