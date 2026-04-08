document.addEventListener("DOMContentLoaded", () => {
    // 1. Initialiseer Konva Stage
    const stage = new Konva.Stage({
        container: "container",
        width: window.innerWidth-360 ,
        height: window.innerHeight - 200
    });
    stage.scale({ x: 1/1.5, y: 1/1.5 });

    const lineLayer = new Konva.Layer();
    const nodeLayer = new Konva.Layer();
    stage.add(lineLayer, nodeLayer);

    const nodeById = new Map();
    const lines = [];

    // 2. Functie om de data te laden en te tekenen
    function loadDrawing(drawingName) {
        if (!drawingName || drawingName === "none") return;

        // Reset lagen
        lineLayer.destroyChildren();
        nodeLayer.add(new Konva.Group()); // Forceer refresh
        nodeLayer.destroyChildren();
        nodeById.clear();
        lines.length = 0;

        fetch(`/api/json/page/${drawingName}`)
            .then(r => r.json())
            .then(objects => {
                const imageLoads = [];

                // Eerste pass: Teken de Nodes (PNG's)
                objects.filter(o => o.tbl !== "line").forEach(obj => {
                    const img = new Image();
                    img.src = `/logo_${obj.type}.png`;

                    const p = new Promise(resolve => {
                        img.onload = () => {
                            const group = new Konva.Group({
                                x: parseInt(obj.xcoord) || 100,
                                y: parseInt(obj.ycoord) || 100,
                                draggable: true
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

                            obj.konvaGroup = group;
                            obj.konvaIcon  = icon;
                            obj.konvaLabel = label;


                            group.on("dragmove", () => updateLinesForNode(group));

                            // Save new position when drag ends
                            group.on("dragend", () => {
                                const newX = group.x();
                                const newY = group.y();
                    
                                                    fetch("/api/moveobject", {
                                    method: "POST",
                                    headers: { "Content-Type": "application/json" },
                                    body: JSON.stringify({
                                        tbl: obj.tbl,
                                        item: obj.item,
					page: obj.page,
                                        xcoord: newX,
                                        ycoord: newY
                                    })
                                }).catch(err => console.error("Move failed:", err));
                            });
                            group.on("mousedown", () => { fillObjectTable(obj); });
                            group.on("dragstart", () => { fillObjectTable(obj); });


                            nodeLayer.add(group);
                            nodeById.set(obj.dr_obj, group);
                            resolve();
                        };
                        img.onerror = resolve; // Ga door, ook als plaatje mist
                    });
                    imageLoads.push(p);
                });

                // Tweede pass: Teken de lijnen zodra de nodes er zijn
                Promise.all(imageLoads).then(() => {
                    objects.filter(o => o.tbl === "line").forEach(obj => {
                        const fromNode = nodeById.get(obj.from);
                        const toNode = nodeById.get(obj.to);
                        if (fromNode && toNode) {
                            const line = new Konva.Line({
                                points: [fromNode.x(), fromNode.y(), toNode.x(), toNode.y()],
                                stroke: obj.color ||"black",
                                strokeWidth: obj.thick ||1
                            });
                            lineLayer.add(line);
                            lines.push({ line, from: fromNode, to: toNode });
                        }
                    });
                    lineLayer.draw();
                    nodeLayer.draw();
                });
            })
            .catch(err => console.error("Fout bij ophalen tekening:", err));
    }

    function updateLinesForNode(node) {
        lines.forEach(entry => {
            if (entry.from === node || entry.to === node) {
                entry.line.points([entry.from.x(), entry.from.y(), entry.to.x(), entry.to.y()]);
            }
        });
        lineLayer.batchDraw();
    }

    // 3. Luister naar veranderingen in de dropdown
    // We gebruiken 'change' op het document omdat de dropdown dynamisch wordt gemaakt
    document.addEventListener("change", (event) => {
        if (event.target && event.target.id === "drawingSelect") {
            loadDrawing(event.target.value);
        }
    });

    // 4. Wacht heel even tot main.tt de lijst heeft gevuld en laad dan de eerste selectie
    setTimeout(() => {
        const select = document.getElementById("drawingSelect");
        if (select && select.value !== "none") {
            loadDrawing(select.value);
        }
    }, 300); 
});
