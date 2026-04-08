document.addEventListener("DOMContentLoaded", () => {
    buildDashboardTable();
    setInterval(buildDashboardTable, 300000); // refresh every 5 minutes
});

function buildDashboardTable() {
    const table = document.getElementById("dashboardTable");
    table.innerHTML = "";

    fetch("/api/json/dashboard")
        .then(r => r.json())
        .then(rows => {
            // Group by server
            const groups = {};
            rows.forEach(row => {
                if (!groups[row.server]) groups[row.server] = [];
                groups[row.server].push(row);
            });

            // Build table
            Object.keys(groups).forEach(serverName => {
                const serverRows = groups[serverName];

                // Header row for each server
                const header = document.createElement("tr");
                const th = document.createElement("th");
                th.colSpan = 3;
                th.textContent = serverName;
                header.appendChild(th);
                table.appendChild(header);

                // Data rows
                serverRows.forEach(item => {
    if (item.type === "val") {
        // --- VAL TYPE: two-row layout with rowspan ---

        // First row
        const tr1 = document.createElement("tr");

        // Variable cell with rowspan=2
        const tdVar = document.createElement("td");
        tdVar.textContent = item.variable;
        tdVar.rowSpan = 2;

        // Value cell (colored)
        const tdVal = document.createElement("td");
        tdVal.textContent = item.value;
        tdVal.style.color = item.color1;

        tr1.appendChild(tdVar);
        tr1.appendChild(tdVal);

        table.appendChild(tr1);

        // Second empty row
        const tr2 = document.createElement("tr");
        table.appendChild(tr2);

    } else if (item.type === "pct") {
        // --- PCT TYPE: normal single-row layout ---

        const tr = document.createElement("tr");

        // Variable
        const tdVar = document.createElement("td");
        tdVar.textContent = item.variable;

        // Bar
        const tdVal = document.createElement("td");

        const pct = parseInt(item.value, 10);

        const bar = document.createElement("div");
        bar.className = "dashboard-bar";

        const fill = document.createElement("div");
        fill.className = "dashboard-bar-fill";
        fill.style.width = pct + "%";
        fill.style.background = item.color1;

        const rest = document.createElement("div");
        rest.className = "dashboard-bar-fill";
        rest.style.width = (100 - pct) + "%";
        rest.style.background = item.color2;

        bar.appendChild(fill);
        bar.appendChild(rest);

        tdVal.appendChild(bar);

        tr.appendChild(tdVar);
        tr.appendChild(tdVal);
                    table.appendChild(tr);
	}
                });
            });
        });
}

