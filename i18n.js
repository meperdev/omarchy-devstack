.pragma library

// Diccionario del widget. `en` es el idioma de publicación (mercado, README,
// capturas) y `es` el de uso diario; el idioma activo vive en
// ~/.config/devstack/lang y se cambia con el botoncito del popup o con
// `devstack lang es`.
//
// Uso desde Panel.qml:  I18n.t("open")  ·  I18n.t("lifting", { seconds: 7 })

var strings = {
    en: {
        // estado
        noData: "No data",
        noProject: "No project",
        noProjectPick: "No project · pick one below",
        undeclared: "Not declared · ",
        stopped: "Stopped",
        up: "Up",
        upCompiling: "Up · compiling",
        partial: "Partial · missing ",
        allUp: "Everything up · ",
        allStopped: "All stopped",
        upShort: "up",
        starting: "Starting… ",
        stopping: "Stopping… ",
        lifting: "Lifting… ",
        didNotFinish: "Did not finish lifting",
        serviceNotResponding: "Service not responding",
        failed: "Failed: ",
        serviceNoAnswer: " · a service is not answering",
        tookOver: "Taking over…",
        stuckHint: "did not finish lifting (check the logs)",
        stoppingAll: "Stopping everything… ",
        portConflict: "Port :{port} is held by {owner}",
        projectsConflict: "{n} with port conflicts",
        ownedBy: " · held by {owner}",
        clickToPin: "Click to pin",
        clickToUnpin: "Click to unpin",
        // origen del proyecto
        originPinned: " · pinned",
        originFocus: " · focus",
        originDefault: " · default",
        // filas de proyecto
        liftingRow: "lifting…",
        services: "serv.",
        projectsWithStack: " projects with a stack",
        foreign: " ·foreign",
        // acciones
        lift: "Lift",
        drop: "Drop",
        open: "Open",
        logs: "Logs",
        restart: "Restart",
        menu: "Menu",
        liftMissing: "Lift what is missing",
        dropAll: "Drop everything",
        stopEverything: "Stop everything",
        unpin: "Unpin",
        find: "Find projects",
        findAgain: "Search again",
        searching: "Searching…",
        back: "Back",
        nothingFound: "I found nothing in your folders",
        declareThis: "Declare this stack",
        movePort: "Move port :",
        takeoverOne: "Take control of {label}",
        takeoverMany: "Take control ({n} ports)",
        // avisos
        clashWarning: " shared with another project: the one listening may be the other one's",
        eyebrow: "",
        // ajustes del chip de idioma
        language: "Language"
    },
    es: {
        noData: "Sin datos",
        noProject: "Sin proyecto",
        noProjectPick: "Sin proyecto · elegí uno abajo",
        undeclared: "Sin declarar · ",
        stopped: "Detenido",
        up: "Arriba",
        upCompiling: "Arriba · compilando",
        partial: "Parcial · falta ",
        allUp: "Todo arriba · ",
        allStopped: "Todo detenido",
        upShort: "arriba",
        starting: "Levantando… ",
        stopping: "Bajando… ",
        lifting: "Levantando… ",
        didNotFinish: "No terminó de levantar",
        serviceNotResponding: "Servicio sin responder",
        failed: "Falló: ",
        serviceNoAnswer: " · un servicio no responde",
        tookOver: "Tomando el control…",
        stuckHint: "no terminó de levantar (mirá los logs)",
        stoppingAll: "Bajando todo… ",
        portConflict: "El puerto :{port} lo tiene {owner}",
        projectsConflict: "{n} con puertos cruzados",
        ownedBy: " · lo tiene {owner}",
        clickToPin: "Click para fijar",
        clickToUnpin: "Click para quitar el fijado",
        originPinned: " · fijado",
        originFocus: " · foco",
        originDefault: " · por defecto",
        liftingRow: "levantando…",
        services: "serv.",
        projectsWithStack: " proyectos con stack",
        foreign: " ·ajeno",
        lift: "Levantar",
        drop: "Bajar",
        open: "Abrir",
        logs: "Logs",
        restart: "Reiniciar",
        menu: "Menú",
        liftMissing: "Levantar lo que falta",
        dropAll: "Bajar todo",
        stopEverything: "Apagar todo",
        unpin: "Quitar el fijado",
        find: "Buscar proyectos",
        findAgain: "Buscar de nuevo",
        searching: "Buscando…",
        back: "Volver",
        nothingFound: "No encontré nada en tus carpetas",
        declareThis: "Declarar este stack",
        movePort: "Mover el puerto :",
        takeoverOne: "Tomar el control de {label}",
        takeoverMany: "Tomar el control ({n} puertos)",
        clashWarning: " compartido con otro proyecto: el que escucha puede ser el del otro",
        eyebrow: "",
        language: "Idioma"
    }
}

// t("open") o t("lifting", { seconds: 7 }): los {nombre} se reemplazan.
function t(lang, key, subs) {
    var table = strings[lang] || strings.en
    var text = table[key]
    if (text === undefined) text = strings.en[key]
    if (text === undefined) return key
    if (subs) {
        for (var name in subs) {
            text = text.split("{" + name + "}").join(String(subs[name]))
        }
    }
    return text
}
