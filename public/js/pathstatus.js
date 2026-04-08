document.addEventListener("DOMContentLoaded", () => {
    console.log("pathstatus.js loaded");
    buildPathOverview();
    setInterval(buildPathOverview, 300000); // refresh every 5 minutes
});

function buildPathOverview() {
    const table = document.getElementById("pathOverview");
    table.innerHTML = "";

    // Step 1: fetch config
    fetch("/api/json/config")
        .then(r => r.json())
        .then(config => {
            const inet = config.find(c => c.item === "inetup");
            const idpath = config.find(c => c.item === "idpath");

            const internetStatus = inet ? inet.value : "unknown";
            const pathIds = idpath ? idpath.value.split(":") : [];

            // Step 2: fetch servers
            fetch("/api/json/servers")
                .then(r => r.json())
                .then(servers => {
                    // Build ordered list: Internet first, then path servers
                    const rows = [];

                    // --- Internet row ---
                    rows.push({
                        logo: "/images/logo_internet.png",
                        name: "Internet",
                        status: internetStatus
                    });

                    // --- Path servers ---
                    pathIds.slice().reverse().forEach(id => {
                        const srv = servers.find(s => String(s.id) === String(id));
                        if (srv) {
                            rows.push({
                                logo: `/images/logo_${srv.type}.png`,
                                name: srv.name,
                                status: srv.status
                            });
                        }
                    });

                    // Render table
                    rows.forEach(row => {
                        const tr = document.createElement("tr");

                        // Logo
                        const tdLogo = document.createElement("td");
                        const img = document.createElement("img");
                        img.src = row.logo;
                        img.className = "server-logo";
                        tdLogo.appendChild(img);

                        // Name
                        const tdName = document.createElement("td");
                        tdName.textContent = row.name;

                        // Status
                        const tdStatus = document.createElement("td");
                        tdStatus.textContent = row.status;

                        if (row.status === "down") tdStatus.style.background = "#f88";
                        if (row.status === "up") tdStatus.style.background = "#8f8";

                        tr.appendChild(tdLogo);
                        tr.appendChild(tdName);
                        tr.appendChild(tdStatus);

                        table.appendChild(tr);
                    });
                });
        });
}

