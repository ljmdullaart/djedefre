function buildServerOverview() {
    const table = document.getElementById("serverOverview");
    table.innerHTML = "";

    fetch("/api/json/servers")
        .then(r => r.json())
        .then(servers => {

            // Filter out network devices
            const filtered = servers.filter(s => s.devicetype !== "network");

            // Sort by status
            const order = { down: 0, up: 1, excluded: 2 };
            filtered.sort((a, b) => order[a.status] - order[b.status]);

            filtered.forEach(server => {
                const tr = document.createElement("tr");

                // --- Logo ---
                const tdLogo = document.createElement("td");
                const img = document.createElement("img");
                img.src = `/images/logo_${server.type}.png`;
                img.className = "server-logo";
                tdLogo.appendChild(img);

                // --- Name ---
                const tdName = document.createElement("td");
                tdName.textContent = server.name;

                // --- STATUS COLUMN ---
                const tdStatus = document.createElement("td");
                tdStatus.textContent = server.status;

                if (server.status === "down") tdStatus.style.background = "#f88";
                if (server.status === "up") tdStatus.style.background = "#8f8";

                // --- BUTTON COLUMN ---
                const tdButton = document.createElement("td");
                tdButton.style.textAlign = "right";

                const btn = document.createElement("button");
                btn.textContent = server.status === "excluded" ? "Include" : "Exclude";
                btn.className = "toggle-status";
                btn.dataset.server = JSON.stringify(server);

                btn.addEventListener("click", function () {
                    const srv = JSON.parse(this.dataset.server);
                    toggleServerStatus(srv);
                });

                tdButton.appendChild(btn);

                // --- Append row ---
                tr.appendChild(tdLogo);
                tr.appendChild(tdName);
                tr.appendChild(tdStatus);
                tr.appendChild(tdButton);

                table.appendChild(tr);
            });
        })
        .catch(err => console.error("Failed to fetch servers:", err));
}


function toggleServerStatus(server) {
    const newStatus = server.status === "excluded" ? "up" : "excluded";

    const payload = {
        item: server.item,
        id: server.id,
        tbl: server.tbl,
        var: "status",
        val: newStatus
    };

    fetch("/api/changeobject", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
    })
    .then(r => r.json())
    .then(() => buildServerOverview())
    .catch(err => console.error("Status toggle failed:", err));
}


// --- Initial load + auto-refresh ---
document.addEventListener("DOMContentLoaded", () => {
    console.log("serverstatus.js loaded");

    buildServerOverview();
    setInterval(buildServerOverview, 300000); // 5 minutes
});

