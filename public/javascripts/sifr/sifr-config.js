var american_typewriter = { src: '/sifr/american_typewriter.swf' };

sIFR.replaceNonDisplayed = true;
sIFR.fitExactly = true;
sIFR.prefetch(american_typewriter);
sIFR.activate();

sIFR.replace(american_typewriter, {
  selector: 'div#body h1',
  tuneHeight: -7,
  css: {
    '.sIFR-root': { 
      'font-weight': 'bold', 
      'color': '#464A52',
      'background-color': '#ffffff'
    }
  }
});

sIFR.replace(american_typewriter, {
  selector: 'div#sidebar div.block h3',
  wmode: 'transparent',
  tuneHeight: -5,
  selector: 'div#sidebar h3',
  css: {
    '.sIFR-root': { 
      'font-weight': 'bold', 
      'color': '#ffffff', 
      'background-color': '#ADAFAF'
    }
  }
});

sIFR.replace(american_typewriter, {
  selector: 'div#footer h3',
  wmode: 'transparent',
  tuneHeight: -5,
  css: {
    '.sIFR-root': { 
      'font-weight': 'bold', 
      'color': '#ffffff', 
      'background-color': '#464A52'
    }
  }
});