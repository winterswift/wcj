/* other support functions -- thanks, ecmanaut! */
var strftime_funks = {
  zeropad: function( n ){ return n>9 ? n : '0'+n; },
  a: function(t) { return ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][t.getDay()] },
  A: function(t) { return ['Sunday','Monday','Tuedsay','Wednesday','Thursday','Friday','Saturday'][t.getDay()] },
  b: function(t) { return ['Jan','Feb','Mar','Apr','May','Jun', 'Jul','Aug','Sep','Oct','Nov','Dec'][t.getMonth()] },
  B: function(t) { return ['January','February','March','April','May','June', 'July','August',
      'September','October','November','December'][t.getMonth()] },
  c: function(t) { return t.toString() },
  d: function(t) { return this.zeropad(t.getDate()) },
  H: function(t) { return this.zeropad(t.getHours()) },
  I: function(t) { return this.zeropad((t.getHours() + 12) % 12) },
  m: function(t) { return this.zeropad(t.getMonth()+1) }, // month-1
  M: function(t) { return this.zeropad(t.getMinutes()) },
  p: function(t) { return this.H(t) < 12 ? 'AM' : 'PM'; },
  S: function(t) { return this.zeropad(t.getSeconds()) },
  w: function(t) { return t.getDay() }, // 0..6 == sun..sat
  y: function(t) { return this.zeropad(this.Y(t) % 100); },
  Y: function(t) { return t.getFullYear() },
  '%': function(t) { return '%' }
};

Date.prototype.strftime = function (fmt) {
    var t = this;
    for (var s in strftime_funks) {
        if (s.length == 1 )
            fmt = fmt.replace('%' + s, strftime_funks[s](t));
    }
    return fmt;
};

if (typeof(TrimPath) != 'undefined') {
    TrimPath.parseTemplate_etc.modifierDef.strftime = function (t, fmt) {
        return new Date(t).strftime(fmt);
    }
}

function toggleClassName(element, className) {
  if (Element.hasClassName(element, className))
    Element.removeClassName(element, className);
  else
    Element.addClassName(element, className);
}

function updateWordCount(event) {
  var textarea = Event.element(event);
  var words_required = parseInt($('words-required').innerHTML);
  var words = countWords(textarea.value);
  var completion_ratio = parseFloat(words) / parseFloat(words_required);

  if (words > words_required) {
    Element.removeClassName('progress', 'yellow');
    Element.addClassName('progress', 'red');
  } else if (words < words_required) {
    Element.removeClassName('progress', 'red');
    Element.addClassName('progress', 'yellow');
  } else if (words == words_required) {
    Element.removeClassName('progress', 'yellow');
    Element.removeClassName('progress', 'red');
  } else {
    // Do nothing
  }

  $('words').update(words);
  //new Effect.Scale('completion-ratio', 1, {scaleX: true, scaleY: false, scaleFrom: 100, scaleTo: ((parseFloat($('completion_ratio').style.width) / 100) / completion_ratio) * 100, restoreAfterFinish: false});
  $('completion-ratio').style.width = Math.round((completion_ratio >= 1 ? 1 : completion_ratio) * 535) + 'px'; //update(Math.round(completion_ratio * 100) + '%');
  var line_breaks = textarea.value.split('\n').length - 1;
  words = words < words_required ? words_required : words;
  var new_height = (Math.ceil((words > 0 ? words : 1) / 13) + line_breaks) * 24;
  textarea.style.height = new_height + 'px';
  $('pagecurl').style.height = (new_height + 25) + 'px';
}

function countWords (value) {
  value = value + ' ';
  var compressible_whitespace = /\s+/gi;
  var removable_non_alpha = /[^\w\s]+/gi;
  var fillable_non_alpha = /([^\w\s]\s)|(\s[^\w\s])|[,;+]/gi;
  value = value.replace(fillable_non_alpha, ' ')
  value = value.replace(removable_non_alpha, '')
  value = value.replace(compressible_whitespace,' ');
  
  return (value != ' ' ? value.split(' ').length - 1 : 0) + '';
}

function toggleElements(firstElement, secondElement) {
  $(firstElement).hide();
  $(secondElement).show()
}

function clearField(event) {
  var field = Event.element(event);
  if (field.value == 'Replace this text...') {
    field.value = '';
    Element.removeClassName(field, 'auto-clear');
  };
}

function init() {
  $$('a.signup').onclick = function() {
    Effect.toggle('signup-form', 'blind');
    return false;
  }
  
  if ($('entry_body')) {
    Event.observe('entry_body', 'keyup', updateWordCount);
    Event.observe('entry_body', 'focus', clearField);
  }
}

Event.observe(window, 'load', init);