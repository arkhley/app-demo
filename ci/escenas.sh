#!/bin/bash
set -u
APP="$1"
SALIDA="$2"
mkdir -p "$SALIDA"
BUNDLE=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")

RUNTIME=$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
r = [x for x in json.load(sys.stdin)["runtimes"] if x["platform"] == "iOS" and x["isAvailable"]]
r.sort(key=lambda x: [int(p) for p in x["version"].split(".")])
print(r[-1]["identifier"])')

TIPO=""
for NOMBRE in "iPhone 17 Pro Max" "iPhone 18 Pro Max" "iPhone 17 Pro" "iPhone 17"; do
  TIPO=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
t = [d["identifier"] for d in json.load(sys.stdin)["devicetypes"] if d["name"] == sys.argv[1]]
print(t[0] if t else "")' "$NOMBRE")
  [ -n "$TIPO" ] && break
done
UDID=$(xcrun simctl create "Captura" "$TIPO" "$RUNTIME")
echo "$NOMBRE · $RUNTIME" | tee "$SALIDA/../simulador.txt"

xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" -b > /dev/null
xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active \
  --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl install "$UDID" "$APP"
LISTA="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)/tmp/maqueta-lista"

es_carga() {   # archivo, huella: ¿es la pantalla de carga?
  [ -s "$1" ] || return 1
  [ -n "${CARGAS:-}" ] && [[ " $CARGAS " == *" $2 "* ]] && return 0
  [ "$(stat -f%z "$1" 2>/dev/null || echo 999999)" -lt 105000 ]
}

foto() {   # nombre, y después los argumentos de la escena
  local nombre="$1"; shift
  xcrun simctl terminate "$UDID" "$BUNDLE" > /dev/null 2>&1 || true
  rm -f "$LISTA"
  xcrun simctl launch "$UDID" "$BUNDLE" "$@" -AppleLanguages "(es-ES)" -AppleLocale es_ES > /dev/null
  local tope="${ESPERA:-8}" desde=$SECONDS antes="" ahora="" tmp="$SALIDA/.tmp.png" nota=""
  while [ ! -e "$LISTA" ] && [ $((SECONDS - desde)) -lt 60 ]; do sleep 0.5; done
  [ -e "$LISTA" ] || nota=" ⚠ sin salir de la carga"
  local listo=$SECONDS
  sleep 3
  while :; do
    xcrun simctl io "$UDID" screenshot --type=png "$tmp" > /dev/null 2>&1 || break
    ahora=$(md5 -q "$tmp")
    [ "$ahora" = "$antes" ] && break
    [ $((SECONDS - listo)) -ge "$tope" ] && break
    antes="$ahora"
    sleep 1
  done
  if es_carga "$tmp" "$ahora"; then
    local hasta=$((SECONDS + 25))
    while [ $SECONDS -lt $hasta ]; do
      sleep 1
      xcrun simctl io "$UDID" screenshot --type=png "$tmp" > /dev/null 2>&1 || break
      ahora=$(md5 -q "$tmp")
      es_carga "$tmp" "$ahora" || break
    done
    if es_carga "$tmp" "$ahora"; then
      if [ -z "${REPITIENDO:-}" ]; then
        echo "  ↻ $nombre (se quedó en la pantalla de carga: otra vez)"
        REPITIENDO=1 foto "$nombre" "$@"
        return
      fi
      nota="$nota ⚠ se quedó en la carga"
    else
      local salio=$SECONDS
      antes=""
      while :; do
        xcrun simctl io "$UDID" screenshot --type=png "$tmp" > /dev/null 2>&1 || break
        ahora=$(md5 -q "$tmp")
        [ "$ahora" = "$antes" ] && break
        [ $((SECONDS - salio)) -ge "$tope" ] && break
        antes="$ahora"
        sleep 1
      done
      nota="$nota (tardó en salir de la carga)"
    fi
  fi
  if [ -s "$tmp" ] && mv "$tmp" "$SALIDA/$nombre.png"; then
    echo "  ✓ $nombre ($((SECONDS - desde)) s)$nota"
  else
    echo "  ✗ $nombre"
  fi
}

video() {   # nombre, segundos tras salir de la carga, y después los argumentos de la escena
  local nombre="$1" seg="$2"; shift 2
  xcrun simctl terminate "$UDID" "$BUNDLE" > /dev/null 2>&1 || true
  rm -f "$LISTA" "$SALIDA/$nombre.mp4"
  xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$SALIDA/$nombre.mp4" > /dev/null 2>&1 &
  local grabando=$!
  sleep 2
  xcrun simctl launch "$UDID" "$BUNDLE" "$@" -AppleLanguages "(es-ES)" -AppleLocale es_ES > /dev/null
  local desde=$SECONDS
  while [ ! -e "$LISTA" ] && [ $((SECONDS - desde)) -lt 60 ]; do sleep 0.2; done
  sleep "$seg"
  kill -INT "$grabando" 2>/dev/null
  wait "$grabando" 2>/dev/null
  if [ -s "$SALIDA/$nombre.mp4" ]; then
    echo "  ✓ $nombre.mp4 ($(stat -f%z "$SALIDA/$nombre.mp4") bytes)"
  else
    echo "  ✗ $nombre.mp4"
  fi
}

GRUPOS="${GRUPOS:-repaso9}"

CARGAS=""
for ASPECTO in dark light; do
  xcrun simctl ui "$UDID" appearance "$ASPECTO"
  xcrun simctl terminate "$UDID" "$BUNDLE" > /dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE" -estado comprobando -AppleLanguages "(es-ES)" -AppleLocale es_ES > /dev/null
  sleep 6
  if xcrun simctl io "$UDID" screenshot --type=png "$SALIDA/.carga.png" > /dev/null 2>&1; then
    CARGAS="$CARGAS $(md5 -q "$SALIDA/.carga.png")"
  fi
done
rm -f "$SALIDA/.carga.png"

if [[ " $GRUPOS " == *" impuestos "* ]]; then
  for ASPECTO in light dark; do
    xcrun simctl ui "$UDID" appearance "$ASPECTO"
    A=$([ "$ASPECTO" = light ] && echo claro || echo oscuro)
    ESPERA=10 foto "impuestos-$A" -pestana agenda -abrir impuestos
    ESPERA=10 foto "impuestos-cuadra-$A" -escena impuestosCuadra -pestana agenda -abrir impuestos
  done
  xcrun simctl ui "$UDID" appearance light
  ESPERA=13 foto "impuestos-porque-claro" -pestana agenda -abrir porque
  ESPERA=10 foto "impuestos-nocuadra-claro" -escena impuestosNoCuadra -pestana agenda -abrir impuestos
  ESPERA=10 foto "impuestos-2T-claro" -pestana agenda -abrir impuestos -trimestre 2026-2T
  ESPERA=10 foto "impuestos-4T-claro" -pestana agenda -abrir impuestos -trimestre 2026-4T
  ESPERA=10 foto "impuestos-abajo-claro" -pestana agenda -abrir impuestos -bajar 1
  ESPERA=10 foto "impuestos-final-claro" -pestana agenda -abrir impuestos -bajar 2
  xcrun simctl ui "$UDID" content_size accessibility-extra-extra-extra-large
  ESPERA=10 foto "impuestos-letra-maxima" -pestana agenda -abrir impuestos
  xcrun simctl ui "$UDID" content_size large
fi

if [[ " $GRUPOS " == *" joyas "* ]]; then
  for ASPECTO in light dark; do
    xcrun simctl ui "$UDID" appearance "$ASPECTO"
    A=$([ "$ASPECTO" = light ] && echo claro || echo oscuro)
    foto "joya-sala-$A" -pestana sala
  done
  ESPERA=10 foto "joya-sala-directo-oscuro" -escena salaDirecto -pestana sala
  xcrun simctl ui "$UDID" appearance light
  foto "joya-cobros-claro" -pestana cobros
  foto "joya-agenda-claro" -escena agendaLlena -pestana agenda
fi

if [[ " $GRUPOS " == *" agenda "* ]]; then
  for ASPECTO in light dark; do
    xcrun simctl ui "$UDID" appearance "$ASPECTO"
    A=$([ "$ASPECTO" = light ] && echo claro || echo oscuro)
    foto "agenda-$A" -pestana agenda
    foto "agenda-llena-$A" -escena agendaLlena -pestana agenda
    foto "agenda-aldia-$A" -escena agendaVacia -pestana agenda
  done
  xcrun simctl ui "$UDID" appearance light
  foto "agenda-llena-abajo-claro" -escena agendaLlena -pestana agenda -bajar 2
  ESPERA=10 foto "agenda-nueva-claro" -pestana agenda -abrir nueva
  xcrun simctl ui "$UDID" content_size accessibility-extra-extra-extra-large
  foto "agenda-letra-maxima" -escena agendaLlena -pestana agenda
  xcrun simctl ui "$UDID" content_size large
fi

if [[ " $GRUPOS " == *" pedidos "* ]]; then
  for ASPECTO in light dark; do
    xcrun simctl ui "$UDID" appearance "$ASPECTO"
    A=$([ "$ASPECTO" = light ] && echo claro || echo oscuro)
    foto "pedidos-$A" -pestana pedidos
    ESPERA=10 foto "pedidos-ficha-$A" -pestana pedidos -abrir pedido
  done
  xcrun simctl ui "$UDID" appearance light
  foto "pedidos-nuevo-claro" -escena pedidoNuevo -pestana pedidos
fi

if [[ " $GRUPOS " == *" cobros "* ]]; then
  for ASPECTO in light dark; do
    xcrun simctl ui "$UDID" appearance "$ASPECTO"
    A=$([ "$ASPECTO" = light ] && echo claro || echo oscuro)
    foto "cobros-$A" -pestana cobros
  done
  foto "cobros-adelanto-oscuro" -pestana cobros -cobro 1
  xcrun simctl ui "$UDID" appearance light
  foto "cobros-elegido-claro" -pestana cobros -cobro 6
  foto "cobros-apartar-claro" -escena apartar -pestana cobros
  foto "cobros-abajo-claro" -pestana cobros -bajar 1
  foto "cobros-final-claro" -pestana cobros -bajar 2 -abrir mes
  xcrun simctl ui "$UDID" content_size accessibility-extra-extra-extra-large
  foto "cobros-letra-maxima" -pestana cobros
  xcrun simctl ui "$UDID" content_size large
fi

if [[ " $GRUPOS " == *" sala "* ]]; then
  for ASPECTO in light dark; do
    xcrun simctl ui "$UDID" appearance "$ASPECTO"
    A=$([ "$ASPECTO" = light ] && echo claro || echo oscuro)
    foto "sala-$A" -pestana sala
    ESPERA=10 foto "sala-directo-$A" -escena salaDirecto -pestana sala
  done
  xcrun simctl ui "$UDID" appearance light
  foto "sala-repeticion-claro" -pestana sala -minuto 55
  foto "sala-abajo-claro" -pestana sala -bajar 1
  foto "sala-final-claro" -pestana sala -bajar 2
  ESPERA=10 foto "sala-directo-final-claro" -escena salaDirecto -pestana sala -bajar 2
  foto "sala-antigua-claro" -escena salaAntigua -pestana sala
  ESPERA=10 foto "sala-chat-claro" -escena salaDirecto -pestana sala -abrir chat
  xcrun simctl ui "$UDID" content_size accessibility-extra-extra-extra-large
  foto "sala-letra-maxima" -pestana sala
  xcrun simctl ui "$UDID" content_size large
fi

if [[ " $GRUPOS " == *" inicio "* ]]; then
for ASPECTO in light dark; do
  xcrun simctl ui "$UDID" appearance "$ASPECTO"
  A=$([ "$ASPECTO" = light ] && echo claro || echo oscuro)
  foto "marcador-mitad-$A" -escena mitad
  foto "marcador-dia4-$A" -escena descansar
  foto "marcador-abajo-$A" -escena mitad -bajar 1
  foto "marcador-plataforma1-$A" -escena mitad -plataforma plataforma1
  foto "marcador-directo-$A" -escena cubierto
  ESPERA=10 foto "marcador-hoja-$A" -escena mitad -abrir prevision
done
xcrun simctl ui "$UDID" appearance light
foto "marcador-plataforma2-claro" -escena mitad -plataforma plataforma2
foto "marcador-tienda-claro" -escena mitad -plataforma tienda
foto "marcador-tienda-abajo-claro" -escena mitad -plataforma tienda -bajar 1
foto "marcador-plataforma1-abajo-claro" -escena mitad -plataforma plataforma1 -bajar 1
foto "marcador-hoy-claro" -escena descansar -periodo dia
foto "marcador-ano-claro" -escena descansar -periodo ano
foto "marcador-quincena-claro" -escena mitad -periodo quincena
foto "marcador-hecho-claro" -escena hecho
xcrun simctl ui "$UDID" appearance dark
foto "marcador-hecho-emitir-oscuro" -escena hechoEmitir
xcrun simctl ui "$UDID" appearance light

xcrun simctl ui "$UDID" content_size accessibility-extra-extra-extra-large
foto "marcador-letra-maxima" -escena mitad
xcrun simctl ui "$UDID" content_size large
fi

claro() { xcrun simctl ui "$UDID" appearance light; }
oscuro() { xcrun simctl ui "$UDID" appearance dark; }
letra() { xcrun simctl ui "$UDID" content_size "$1"; }

if [[ " $GRUPOS " == *" panel "* ]]; then
  claro; foto "panel-claro" -abrir panel
  oscuro; foto "panel-oscuro" -abrir panel
  claro
  for P in 0.08 0.2 0.42; do foto "panel-isla-$P-claro" -abrir panel -progreso "$P"; done
  oscuro; foto "panel-isla-0.2-oscuro" -abrir panel -progreso 0.2
  claro; foto "panel-codigos-claro" -pantalla codigos -abrir panel
  foto "panel-fondo-claro" -abrir panel -fondo demo
  for P in 0.42 0.8; do foto "panel-fondo-$P-claro" -abrir panel -fondo demo -progreso "$P"; done
  oscuro; foto "panel-fondo-oscuro" -abrir panel -fondo demo
  claro; for P in 0 0.5 0.85; do foto "panel-pista-$P-claro" -pista "$P"; done
  oscuro; foto "panel-pista-0-oscuro" -pista 0
  claro; foto "panel-oculta-claro" -abrir panel -ocultar_cifras YES
  for H in tokens adelanto enlaces comprobar; do ESPERA=10 foto "panel-$H-claro" -abrir panel -herramienta "$H"; done
  oscuro; ESPERA=10 foto "panel-tokens-oscuro" -abrir panel -herramienta tokens
  claro; letra accessibility-extra-extra-extra-large
  foto "panel-letra-maxima" -abrir panel
  letra large
fi

if [[ " $GRUPOS " == *" cuenta "* ]]; then
  claro; foto "cuenta-claro" -abrir cuenta
  oscuro; foto "cuenta-oscuro" -abrir cuenta
  claro
  for S in info seguridad faceid claves avisos almacenamiento logs borrar; do foto "cuenta-$S-claro" -abrir cuenta -sub "$S"; done
  oscuro; foto "cuenta-logs-oscuro" -abrir cuenta -sub logs
  claro; letra accessibility-extra-extra-extra-large
  foto "cuenta-letra-maxima" -abrir cuenta
  letra large
fi

if [[ " $GRUPOS " == *" reserva "* ]]; then
  for ASPECTO in light dark; do
    xcrun simctl ui "$UDID" appearance "$ASPECTO"
    A=$([ "$ASPECTO" = light ] && echo claro || echo oscuro)
    foto "reserva-$A" -abrir cuenta -sub reserva
    foto "calendario-$A" -abrir cuenta -sub calendario
  done
  claro
  foto "reserva-abajo-claro" -abrir cuenta -sub reserva -bajar 1
  foto "reserva-final-claro" -abrir cuenta -sub reserva -bajar 2
  foto "calendario-final-claro" -abrir cuenta -sub calendario -bajar 2
  letra accessibility-extra-extra-extra-large
  foto "reserva-letra-maxima" -abrir cuenta -sub reserva
  letra large
fi

if [[ " $GRUPOS " == *" gestion "* ]]; then
  claro; foto "codigos-claro" -pantalla codigos
  oscuro; foto "codigos-oscuro" -pantalla codigos
  foto "plataformas-oscuro" -pantalla plataformas
  claro
  for P in videos categoria plataformas transferencias ajustescb ajustesmanual ajustestienda canal clientes comosecalcula apuntar; do
    foto "$P-claro" -pantalla "$P"
  done
  foto "transferencias-abajo-claro" -pantalla transferencias -bajar 2
  foto "ajustescb-abajo-claro" -pantalla ajustescb -bajar 2
  oscuro
  for P in apuntar canal videos clientes comosecalcula; do
    foto "$P-oscuro" -pantalla "$P"
  done
  claro
fi

if [[ " $GRUPOS " == *" datos "* ]]; then
  for ASPECTO in light dark; do
    xcrun simctl ui "$UDID" appearance "$ASPECTO"
    A=$([ "$ASPECTO" = light ] && echo claro || echo oscuro)
    foto "detalle-$A" -pantalla detalle -plataforma plataforma1
    foto "historial-$A" -pantalla historial
    foto "encargos-$A" -pantalla encargos
  done
  claro
  foto "detalle-abajo-claro" -pantalla detalle -plataforma plataforma1 -bajar 1
  foto "detalle-final-claro" -pantalla detalle -plataforma plataforma1 -bajar 2
  foto "detalle-plataforma2-claro" -pantalla detalle -plataforma plataforma2
  foto "historial-plataforma1-claro" -pantalla historial -plataforma plataforma1
  foto "historial-abajo-claro" -pantalla historial -bajar 2
  foto "encargos-abajo-claro" -pantalla encargos -bajar 2
fi

if [[ " $GRUPOS " == *" impuestos2 "* ]]; then
  claro
  for I in gastos ingresos contactos modelo; do ESPERA=10 foto "impuestos-$I-claro" -pestana agenda -abrir impuestos -imp "$I"; done
  ESPERA=10 foto "impuestos-ajustes-claro" -pestana agenda -abrir impuestos -imp ajustes
  ESPERA=10 foto "impuestos-ingreso-claro" -pestana agenda -abrir impuestos -imp ingreso
  oscuro
  ESPERA=10 foto "impuestos-ingresos-oscuro" -pestana agenda -abrir impuestos -imp ingresos
  ESPERA=10 foto "impuestos-gastos-oscuro" -pestana agenda -abrir impuestos -imp gastos
  claro
fi

if [[ " $GRUPOS " == *" entrada "* ]]; then
  for ASPECTO in light dark; do
    xcrun simctl ui "$UDID" appearance "$ASPECTO"
    A=$([ "$ASPECTO" = light ] && echo claro || echo oscuro)
    foto "bloqueo-$A" -estado bloqueada
    foto "entrar-$A" -estado fuera
  done
  claro
fi

if [[ " $GRUPOS " == *" cerrojo "* ]]; then
  claro
  foto "cerrojo-cara" -estado bloqueada -codigo prueba -cara nunca -fondo demo
  foto "cerrojo-teclado-claro" -estado bloqueada -codigo prueba -fondo demo
  foto "cerrojo-teclado-regular" -estado bloqueada -codigo prueba -fondo demo -cristal regular
  foto "cerrojo-sinfondo-claro" -estado bloqueada -codigo prueba
  foto "cerrojo-nodisponible" -estado bloqueada -codigo prueba -fondo demo -fallos 6
  oscuro
  foto "cerrojo-teclado-oscuro" -estado bloqueada -codigo prueba -fondo demo
  foto "cerrojo-sinfondo-oscuro" -estado bloqueada -codigo prueba
  claro
  video "cerrojo-aparece" 6 -estado bloqueada -codigo prueba -fondo demo -cara espera
fi

if [[ " $GRUPOS " == *" llegada "* ]]; then
  claro
  for T in 0.021 0.141 0.481; do
    foto "llegada-$T" -estado bloqueada -codigo prueba -cara lee -fondo demo -llegada "$T"
  done
  foto "llegada-final" -estado bloqueada -codigo prueba -cara lee -fondo demo
  oscuro
  foto "llegada-0.141-oscuro" -estado bloqueada -codigo prueba -cara lee -fondo demo -llegada 0.141
  claro
  video "llegada" 5 -estado bloqueada -codigo prueba -cara lee -fondo demo
fi

if [[ " $GRUPOS " == *" widget "* ]]; then
  claro
  for E in descansar trabajar riesgo directo cubierto hecho hechoEmitir; do
    foto "widget-$E-claro" -escena "$E" -pantalla widget
  done
  oscuro
  foto "widget-directo-oscuro" -escena directo -pantalla widget
  foto "widget-descansar-oscuro" -escena descansar -pantalla widget
  claro
  foto "widget-oculto-claro" -escena cubierto -pantalla widget -ocultar_cifras YES
  letra accessibility-extra-extra-extra-large
  foto "widget-letra-maxima" -escena cubierto -pantalla widget
  letra large
fi

if [[ " $GRUPOS " == *" vida "* ]]; then
  claro
  for T in otono lluvia nieve cerezo oceano lava corazones fiesta granizo nubes soleado niebla vilanos pompas; do
    foto "vida-inicio-$T-claro" -tema.elegido "$T" -vida.calentar 14
  done
  foto "vida-prevision-otono-claro" -tema.elegido otono -abrir prevision -vida.calentar 14
  foto "vida-prevision-lluvia-claro" -tema.elegido lluvia -abrir prevision -vida.calentar 3
  foto "vida-agenda-otono-claro" -pestana agenda -tema.elegido otono -vida.calentar 14
  foto "vida-sala-nieve-claro" -pestana sala -tema.elegido nieve -vida.calentar 14
  foto "vida-cobros-lluvia-claro" -pestana cobros -tema.elegido lluvia -vida.calentar 3
  foto "vida-cuenta-otono-claro" -abrir cuenta -tema.elegido otono
  foto "vida-panel-otono-claro" -abrir panel -tema.elegido otono -vida.calentar 14
fi

if [[ " $GRUPOS " == *" vida2 "* ]]; then
  oscuro
  for T in estrellada tormenta luciernagas tesoro hoguera aurora oro fuegos galaxia otono lluvia nieve cerezo oceano lava corazones fiesta granizo nubes niebla vilanos; do
    foto "vida2-inicio-$T-oscuro" -tema.elegido "$T" -vida.calentar 14
  done
  foto "vida2-panel-estrellada" -abrir panel -tema.elegido estrellada
  foto "vida2-panel-tormenta" -abrir panel -tema.elegido tormenta -vida.calentar 4
  foto "vida2-sala-tormenta" -pestana sala -tema.elegido tormenta -vida.calentar 4
  foto "vida2-prevision-tesoro" -tema.elegido tesoro -abrir prevision -vida.calentar 14
  claro
fi

if [[ " $GRUPOS " == *" texturas "* ]]; then
  claro
  for T in papel kraft washi lino vaquero terciopelo marmol madera hormigon acuarela libreta cuero arena; do
    foto "tex-inicio-$T-claro" -tema.elegido "$T"
  done
  foto "tex-agenda-madera-claro" -pestana agenda -tema.elegido madera
  foto "tex-cobros-papel-claro" -pestana cobros -tema.elegido papel
  oscuro
  for T in papel kraft washi lino vaquero terciopelo marmol madera hormigon pizarra libreta cianotipo cuero arena carbono escarcha; do
    foto "tex-inicio-$T-oscuro" -tema.elegido "$T"
  done
  claro
fi

if [[ " $GRUPOS " == *" mallas "* ]]; then
  claro
  for T in original cobalto amatista fucsia tropical primavera verano atardecer lavanda opalo salvia invierno tomate mostaza menta chicle lima lila arcilla hueso grafito blanco; do
    foto "malla-inicio-$T-claro" -tema.elegido "$T"
  done
  foto "malla-inicio-tomate-plataforma1-claro" -tema.elegido tomate -plataforma plataforma1
  foto "malla-agenda-cobalto-claro" -pestana agenda -tema.elegido cobalto
  oscuro
  for T in original medianoche cobalto amatista fucsia tropical primavera verano atardecer lavanda opalo salvia neon invierno tomate menta chicle lima lila arcilla hueso klein cereza petroleo grafito negro; do
    foto "malla-inicio-$T-oscuro" -tema.elegido "$T"
  done
  claro
fi

if [[ " $GRUPOS " == *" repaso "* ]]; then
  claro
  foto "repaso-lluvia-inicio-claro" -tema.elegido lluvia -vida.calentar 8
  foto "repaso-lluvia-prevision-claro" -tema.elegido lluvia -abrir prevision -vida.calentar 6
  foto "repaso-otono-prevision-claro" -tema.elegido otono -abrir prevision -vida.calentar 20
  foto "repaso-lluvia-agenda-claro" -pestana agenda -tema.elegido lluvia -vida.calentar 8
  foto "repaso-otono-inicio-claro" -tema.elegido otono -vida.calentar 20
  foto "repaso-fiesta-inicio-claro" -tema.elegido fiesta -vida.calentar 10
  foto "repaso-pompas-inicio-claro" -tema.elegido pompas -vida.calentar 6
  foto "repaso-vilanos-inicio-claro" -tema.elegido vilanos -vida.calentar 10
  for T in acuarela kraft; do
    foto "repaso-tex-$T-claro" -tema.elegido "$T"
  done
  oscuro
  for T in estrellada hoguera luciernagas tormenta lluvia; do
    foto "repaso-$T-oscuro" -tema.elegido "$T" -vida.calentar 10
  done
  for T in kraft escarcha; do
    foto "repaso-tex-$T-oscuro" -tema.elegido "$T"
  done
  foto "repaso-panel-lluvia-oscuro" -abrir panel -tema.elegido lluvia -vida.calentar 8
  claro
fi

if [[ " $GRUPOS " == *" repaso2 "* ]]; then
  claro
  foto "repaso2-lava-claro" -tema.elegido lava -vida.calentar 6
  foto "repaso2-pompas-claro" -tema.elegido pompas -vida.calentar 6
  foto "repaso2-vilanos-claro" -tema.elegido vilanos -vida.calentar 10
  oscuro
  foto "repaso2-lava-oscuro" -tema.elegido lava -vida.calentar 6
  foto "repaso2-galeria-vida-oscuro" -abrir cuenta -sub temas -tema.elegido lava -seccion vida
  claro
  foto "repaso2-galeria-textura-claro" -abrir cuenta -sub temas -tema.elegido papel -seccion textura
fi

if [[ " $GRUPOS " == *" salto "* ]]; then
  claro
  video "salto-cuenta-plano" 10 -abrir cuenta -sub temas -tema.elegido otono -seccion plano -cambiar lima
  video "salto-cuenta-noche" 10 -abrir cuenta -sub temas -tema.elegido tomate -seccion plano -cambiar cereza
  video "salto-hoja-plano" 12 -abrir panel -herramienta tema -tema.elegido otono -seccion plano -cambiar lima
fi

if [[ " $GRUPOS " == *" repaso3 "* ]]; then
  oscuro
  video "repaso3-monedas" 16 -tema.elegido tesoro
  video "repaso3-estrellas" 6 -tema.elegido estrellada
  foto "repaso3-panel-tesoro" -abrir panel -tema.elegido tesoro -vida.calentar 10
  foto "repaso3-nubes-oscuro" -tema.elegido nubes -vida.calentar 20
  foto "repaso3-tex-cuero-oscuro" -tema.elegido cuero
  foto "repaso3-tex-escarcha-oscuro" -tema.elegido escarcha
  claro
  foto "repaso3-nubes-claro" -tema.elegido nubes -vida.calentar 20
  foto "repaso3-niebla-claro" -tema.elegido niebla -vida.calentar 20
  foto "repaso3-panel-blanco" -abrir panel -tema.elegido blanco
  foto "repaso3-panel-mostaza" -abrir panel -tema.elegido mostaza
  foto "repaso3-panel-soleado" -abrir panel -tema.elegido soleado
  foto "repaso3-galeria-lima" -abrir cuenta -sub temas -tema.elegido lima
  foto "repaso3-galeria-hoja-verano" -abrir panel -herramienta tema -tema.elegido verano
  foto "repaso3-tex-acuarela-claro" -tema.elegido acuarela
fi

if [[ " $GRUPOS " == *" repaso4 "* ]]; then
  claro
  for T in blanco mostaza soleado lima otono; do
    foto "repaso4-panel-$T" -abrir panel -tema.elegido "$T"
  done
  oscuro
  for T in cobalto medianoche verano; do
    foto "repaso4-panel-$T-oscuro" -abrir panel -tema.elegido "$T"
  done
  foto "repaso4-monedas-quietas" -tema.elegido tesoro -vida.calentar 14
  video "repaso4-monedas" 16 -tema.elegido tesoro
  claro
fi

if [[ " $GRUPOS " == *" repaso5 "* ]]; then
  claro
  for E in hecho hechoEmitir descansar directo; do
    foto "repaso5-capsula-$E" -escena "$E"
  done
  oscuro
  foto "repaso5-capsula-hecho-tesoro" -escena hecho -tema.elegido tesoro
  video "repaso5-monedas" 16 -escena hecho -tema.elegido tesoro
  claro
fi

if [[ " $GRUPOS " == *" repaso6 "* ]]; then
  oscuro
  video "repaso6-estrellas" 12 -tema.elegido estrellada
  foto "repaso6-estrellas" -tema.elegido estrellada
  foto "repaso6-galaxia" -tema.elegido galaxia
  claro
fi

if [[ " $GRUPOS " == *" repaso7 "* ]]; then
  oscuro
  video "repaso7-monedas" 22 -escena hecho -tema.elegido tesoro
  claro
fi

if [[ " $GRUPOS " == *" repaso8 "* ]]; then
  oscuro
  foto "repaso8-estrellas" -tema.elegido estrellada
  video "repaso8-estrellas" 10 -tema.elegido estrellada
  claro
fi

if [[ " $GRUPOS " == *" repaso9 "* ]]; then
  oscuro
  video "repaso9-monedas-oscuro" 22 -escena hecho -tema.elegido tesoro
  claro
  video "repaso9-monedas-claro" 22 -tema.elegido tesoro
fi

if [[ " $GRUPOS " == *" galeria "* ]]; then
  claro
  foto "galeria-arriba-claro" -abrir cuenta -sub temas -tema.elegido otono
  for S in vida textura difuminado plano; do
    foto "galeria-$S-claro" -abrir cuenta -sub temas -tema.elegido otono -seccion "$S"
  done
  oscuro
  foto "galeria-arriba-oscuro" -abrir cuenta -sub temas -tema.elegido estrellada
  for S in vida textura plano; do
    foto "galeria-$S-oscuro" -abrir cuenta -sub temas -tema.elegido estrellada -seccion "$S"
  done
  foto "galeria-hoja-oscuro" -abrir panel -herramienta tema -tema.elegido lluvia
  claro
fi


ls "$SALIDA" | wc -l | xargs echo "Capturas:"
