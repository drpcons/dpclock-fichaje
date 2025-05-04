// Configuración de Flutter Web
window.addEventListener('load', function() {
  // Configuración de Flutter
  window._flutter = {
    loader: {
      loadEntrypoint: function(options) {
        // Configurar el viewport para accesibilidad
        const viewport = document.querySelector('meta[name="viewport"]');
        if (viewport) {
          viewport.content = 'width=device-width, initial-scale=1.0';
        }

        // Inicializar Flutter
        return new Promise(function(resolve, reject) {
          try {
            _flutter_web_init()
              .then(function() {
                // Configurar el manejo de errores
                window.onerror = function(message, source, lineno, colno, error) {
                  console.error('Error en Flutter Web:', {
                    message: message,
                    source: source,
                    lineno: lineno,
                    colno: colno,
                    error: error
                  });
                  return false;
                };

                // Configurar el service worker si está disponible
                if ('serviceWorker' in navigator) {
                  navigator.serviceWorker.register('flutter_service_worker.js?v=2695861408');
                }

                resolve();
              })
              .catch(reject);
          } catch (e) {
            reject(e);
          }
        });
      }
    }
  };

  // Cargar el script principal de Flutter
  const scriptTag = document.createElement('script');
  scriptTag.src = 'main.dart.js';
  scriptTag.type = 'application/javascript';
  document.body.appendChild(scriptTag);
}); 