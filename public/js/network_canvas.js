// Globale variabelen
window.stage = null;
window.nodeById = new Map();   // key = dr_obj
window.lines = [];             // { line, fromId, toId }
window.loadDrawing = null;
window.redrawNetwork = null;

document.addEventListener("DOMContentLoaded", () => {

    // 1. Stage initialiseren
    window.stage = new Konva.Stage({
        container: "container",
        width: window.innerWidth - 360,
        height: window.innerHeight - 200
    });

    stage.scale({ x: 1 / 1.5, y: 1 / 1.5 });

    const backgroundLayer = new Konva.Layer();
    const lineLayer = new Konva.Layer();
    const nodeLayer = new Konva.Layer();
    stage.add(backgroundLayer, lineLayer, nodeLayer);


    window.nodeById = new Map();
    window.lines = [];

    // 2. Tekening laden en tekenen
    window.loadDrawing = function (drawingName) {
        if (!drawingName || drawingName === "none") return;
        // Reset layers en mappings
	backgroundLayer.destroyChildren();
        loadBackgroundImage(drawingName, backgroundLayer);
        lineLayer.destroyChildren();
        nodeLayer.destroyChildren();
        nodeById.clear();
        lines.length = 0;

        fetch(`/api/json/page/${drawingName}`)
            .then(r => r.json())
            .then(objects => {
                const imageLoads = [];

                // --- Nodes tekenen (alles behalve tbl === "line") ---
                objects.filter(o => o.tbl !== "line").forEach(obj => {
                    const img = new Image();
                    img.src = `/logo_${obj.type}.png`;

                    const p = new Promise(resolve => {
                        img.onload = () => {

                            const group = new Konva.Group({
                                x: parseInt(obj.xcoord) || 100,
                                y: parseInt(obj.ycoord) || 100,
                                draggable: !(obj.fixed === true || obj.fixed === "true")
                            });

                            const icon = new Konva.Image({
                                image: img,
                                offsetX: img.width / 2,
                                offsetY: img.height / 2
                            });

                            const label = new Konva.Text({
                                text: obj.name,
                                fontSize: 14,
                                fill: "black",
                                align: "center",
                                width: 120,
                                offsetX: 60,
                                y: img.height / 2 + 5
                            });

                            group.add(icon, label);

                            // Konva referenties opslaan op het object
                            obj.konvaGroup = group;
                            obj.konvaIcon  = icon;
                            obj.konvaLabel = label;

                            // Node verplaatsen → lijnen updaten
                            group.on("dragmove", () => updateLinesForNode());

                            // Node verplaatsen → positie opslaan
                            group.on("dragend", () => {
                                fetch("/api/moveobject", {
                                    method: "POST",
                                    headers: { "Content-Type": "application/json" },
                                    body: JSON.stringify({
                                        tbl: obj.tbl,
                                        item: obj.item,
                                        page: obj.page,
                                        xcoord: group.x(),
                                        ycoord: group.y()
                                    })
                                }).catch(err => console.error("Move failed:", err));
                            });

                            // Node selecteren → object info tonen
                            group.on("mousedown", () => fillObjectTable(obj));
                            group.on("dragstart", () => fillObjectTable(obj));

                            nodeLayer.add(group);

                            // BELANGRIJK: dr_obj is uniek in de tekening
                            nodeById.set(obj.dr_obj, group);

                            resolve();
                        };

                        img.onerror = resolve;
                    });

                    imageLoads.push(p);
                });

                // --- Lijnen tekenen ---
                Promise.all(imageLoads).then(() => {
                    objects.filter(o => o.tbl === "line").forEach(obj => {
                        const fromNode = nodeById.get(obj.from); // from/to verwijzen naar dr_obj
                        const toNode   = nodeById.get(obj.to);

                        if (fromNode && toNode) {
                            const line = new Konva.Line({
                                points: [fromNode.x(), fromNode.y(), toNode.x(), toNode.y()],
                                stroke: obj.color || "black",
                                strokeWidth: obj.thick || 1
                            });

                            lineLayer.add(line);

                            // Lijn opslaan op basis van dr_obj
                            lines.push({
                                line,
                                fromId: obj.from, // dr_obj van bron
                                toId:   obj.to    // dr_obj van doel
                            });
                        }
                    });

                    lineLayer.draw();
                    nodeLayer.draw();
if (isMobile()) {
    fitToScreen();
}

                });
            })
            .catch(err => console.error("Fout bij ophalen tekening:", err));
    };

    // 3. Lijnen updaten (bij drag)
    function updateLinesForNode() {
        lines.forEach(entry => {
            const fromNode = nodeById.get(entry.fromId);
            const toNode   = nodeById.get(entry.toId);

            if (fromNode && toNode) {
                entry.line.points([
                    fromNode.x(), fromNode.y(),
                    toNode.x(),   toNode.y()
                ]);
            }
        });

        lineLayer.batchDraw();
    }

    // 4. Dropdown change
    document.addEventListener("change", (event) => {
        if (event.target && event.target.id === "drawingSelect") {
            loadDrawing(event.target.value);
        }
    });

    // 5. Eerste tekening laden
    setTimeout(() => {
        const select = document.getElementById("drawingSelect");
        if (select && select.value !== "none") {
            loadDrawing(select.value);
        }
    }, 300);

    // 6. Stage resizing
    function fitStageToContainer() {
        const container = stage.container();
        stage.width(container.offsetWidth);
        stage.height(container.offsetHeight);
        stage.draw();
    }

    window.addEventListener("resize", fitStageToContainer);
    fitStageToContainer();

    // 7. Zoom & pan
    stage.draggable(true);

    stage.on("wheel", (e) => {
        e.evt.preventDefault();

        const scaleBy = 1.05;
        const oldScale = stage.scaleX();
        const pointer = stage.getPointerPosition();

        const mousePointTo = {
            x: (pointer.x - stage.x()) / oldScale,
            y: (pointer.y - stage.y()) / oldScale
        };

        const direction = e.evt.deltaY > 0 ? 1 : -1;
        const newScale = direction > 0 ? oldScale * scaleBy : oldScale / scaleBy;

        stage.scale({ x: newScale, y: newScale });

        stage.position({
            x: pointer.x - mousePointTo.x * newScale,
            y: pointer.y - mousePointTo.y * newScale
        });

        stage.batchDraw();
    });
});

// 8. Globale redraw-functie (voor delete)
window.redrawNetwork = function () {
    const select = document.getElementById("drawingSelect");
    if (select && select.value !== "none") {
        window.loadDrawing(select.value);
    }
};

function getDrawingBounds() {
    let minX = Infinity, minY = Infinity;
    let maxX = -Infinity, maxY = -Infinity;

    nodeById.forEach(group => {
        const x = group.x();
        const y = group.y();

        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
    });

    return { minX, minY, maxX, maxY };
}

function fitToScreen() {
    const { minX, minY, maxX, maxY } = getDrawingBounds();

    const drawingWidth  = maxX - minX;
    const drawingHeight = maxY - minY;

    const container = stage.container();
    const viewWidth  = container.offsetWidth;
    const viewHeight = container.offsetHeight;

    // Bepaal schaalfactor
    const scale = Math.min(
        viewWidth  / drawingWidth,
        viewHeight / drawingHeight
    ) * 0.9; // iets marge

    stage.scale({ x: scale, y: scale });

    // Centreer
    const offsetX = (viewWidth  - drawingWidth  * scale) / 2;
    const offsetY = (viewHeight - drawingHeight * scale) / 2;

    stage.position({
        x: offsetX - minX * scale,
        y: offsetY - minY * scale
    });

    stage.batchDraw();
}

function isMobile() {
    return window.innerWidth < 900; // of gebruik userAgent
}


function loadBackgroundImage(pageName, layer) {
    const img = new Image();
    img.src = `/images/${pageName}.png`;   // or jpg, or whatever your API returns

    img.onload = () => {
        const bg = new Konva.Image({
            image: img,
            x: 0,
            y: 0,
            listening: false   // background should not block clicks
        });

        // Put background at the bottom
        layer.add(bg);
        layer.draw();
    };

    img.onerror = () => {
        console.log("No background image for", pageName);
    };
}

