function fillObjectTable(obj) {
    const table = document.getElementById("objectInfo");
    table.innerHTML = "";   // clear previous content

    // Always add item + name
    addRow(table, "Item", obj.item);
    addEditableRow(table, "Name", obj,"name");
    addTypeRow(table, obj);

    // SERVER
    if (obj.tbl === "server") {
        addRow(table, "OS Type", obj.ostype);
        addRow(table, "OS", obj.os);
        addRow(table, "Processor", obj.processor);
        addRow(table, "Memory", obj.memory);

        // One row containing a sub-table for all interfaces
        if (Array.isArray(obj.interfaces) && obj.interfaces.length > 0) {
            const sub = createInterfacesTable(obj.interfaces);
            addFullRow(table, sub);   // colspan=2
        }
    }

    // SUBNET
    if (obj.tbl === "subnet") {
        addRow(table, "Network Address", obj.nwaddress);
        addRow(table, "CIDR", obj.cidr);
    }
    addPageListRow(table, obj); 

    addDeleteRow(table, obj);
}

function addRow(table, label, value) {
    const tr = document.createElement("tr");

    const th = document.createElement("th");
    th.textContent = label;

    const td = document.createElement("td");
    td.textContent = value ?? "";

    tr.appendChild(th);
    tr.appendChild(td);
    table.appendChild(tr);
}
function addEditableRow(table, label, obj, fieldName) {
    const tr = document.createElement("tr");

    const th = document.createElement("th");
    th.textContent = label;

    const td = document.createElement("td");

    const input = document.createElement("input");
    input.type = "text";
    input.value = obj[fieldName] ?? "";
    input.className = "edit-field";

    // When Enter is pressed → send API call
    input.addEventListener("keydown", (ev) => {
        if (ev.key === "Enter") {
            sendUpdate(obj, fieldName, input.value);
        }
    });

    td.appendChild(input);
    tr.appendChild(th);
    tr.appendChild(td);
    table.appendChild(tr);
}


function addFullRow(table, contentNode) {
    const tr = document.createElement("tr");

    const td = document.createElement("td");
    td.colSpan = 2;

    td.appendChild(contentNode);
    tr.appendChild(td);
    table.appendChild(tr);
}

function createInterfacesTable(interfaces) {
    const sub = document.createElement("table");
    sub.className = "subtable";

    // Header row
    const header = document.createElement("tr");
    ["Name", "MAC", "IP"].forEach(h => {
        const th = document.createElement("th");
        th.textContent = h;
        header.appendChild(th);
    });
    sub.appendChild(header);

    // Data rows
    interfaces.forEach(intf => {
        const tr = document.createElement("tr");

        [intf.ifname, intf.macid, intf.ip].forEach(val => {
            const td = document.createElement("td");
            td.textContent = val ?? "";
            tr.appendChild(td);
        });

        sub.appendChild(tr);
    });

    return sub;
}

function sendUpdate(obj, fieldName, newValue) {
    const payload = {
        item: obj.item,
        tbl: obj.tbl,
        var: fieldName,
        val: newValue
    };

    fetch("/api/changeobject", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
    })
    .then(r => r.json())
    .then(data => {
        console.log("Updated:", data);
        obj[fieldName] = newValue;
        if (fieldName === "name" && obj.konvaLabel) {
            obj.konvaLabel.text(newValue);
            obj.konvaLabel.getLayer().draw();
        }

        if (fieldName === "type" && obj.konvaIcon) {
            const img = new Image();
            img.onload = () => {
                obj.konvaIcon.image(img);
                obj.konvaIcon.getLayer().draw();
            };
            img.src = `/images/logo_${newValue}.png`;
        }
    })
    .catch(err => console.error("Update failed:", err));
}

function addTypeRow(table, obj) {
    const tr = document.createElement("tr");

    const th = document.createElement("th");
    th.textContent = "Type";

    const td = document.createElement("td");

    const select = document.createElement("select");
    select.className = "edit-field";

    // Load options from API
    loadLogoList().then(options => {
        options.forEach(name => {
            const opt = document.createElement("option");
            opt.value = name;
            opt.textContent = name;
            if (name === obj.type) opt.selected = true;
            select.appendChild(opt);
        });
    });

    // When user changes selection → update
    select.addEventListener("change", () => {
        const newType = select.value;
        sendUpdate(obj, "type", newType);
    });

    td.appendChild(select);
    tr.appendChild(th);
    tr.appendChild(td);
    table.appendChild(tr);
}
function loadLogoList() {
    return fetch("/api/logolist")
        .then(r => r.text())
        .then(xmlText => {
            const parser = new DOMParser();
            const xml = parser.parseFromString(xmlText, "application/xml");
            const names = [...xml.getElementsByTagName("name")];
            return names.map(n => n.textContent.trim());
        });
}

function addPageListRow(table, obj) {
    const tr = document.createElement("tr");

    const th = document.createElement("th");
    th.textContent = "Available on pages";

    const td = document.createElement("td");

    const container = document.createElement("div");
    container.className = "page-container";

    // Show current pages with remove buttons
    obj.pagelist.forEach(page => {
	const wrapper = document.createElement("div");
        wrapper.className = "page-entry";

        const nameSpan = document.createElement("span");
        nameSpan.className = "page-name";
        nameSpan.textContent = page;

        const removeBtn = document.createElement("button");
        removeBtn.textContent = "×";
        removeBtn.className = "page-remove";

        removeBtn.addEventListener("click", () => {
            updatePageList(obj, "remove", page);
        });

        wrapper.appendChild(removeBtn);
	wrapper.appendChild(nameSpan);
        container.appendChild(wrapper);
    });

    // Dropdown to add a page
    const select = document.createElement("select");
    select.className = "edit-field";

    loadPageList().then(list => {
        // Only show pages not already in pagelist
        list
            .filter(p => !obj.pagelist.includes(p))
            .forEach(page => {
                const opt = document.createElement("option");
                opt.value = page;
                opt.textContent = page;
                select.appendChild(opt);
            });
    });

    // Add button
    const addBtn = document.createElement("button");
    addBtn.textContent = "Add";
    addBtn.className = "page-add";

    addBtn.addEventListener("click", () => {
        const page = select.value;
        if (page) updatePageList(obj, "add", page);
    });

    container.appendChild(select);
    container.appendChild(addBtn);

    td.appendChild(container);
    tr.appendChild(th);
    tr.appendChild(td);
    table.appendChild(tr);
}

function addDeleteRow(table, obj) {
    const tr = document.createElement("tr");
    const th = document.createElement("th");
    th.textContent = "Delete";
    const td = document.createElement("td");
    const btn = document.createElement("button");
    btn.textContent = "Delete object";
    btn.className = "delete-button";
    btn.addEventListener("click", () => {
const payload = {
        tbl: obj.tbl,
        item: obj.item
    };

    fetch("/api/deleteobject", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
    })
    .then(r => r.json())
    .then(data => {
        console.log("Deleted:", data);

        // 1. verwijder alle lijnen die aan dit object hangen
        lines = lines.filter(entry => {
    if (entry.fromItem === obj.item || entry.toItem === obj.item) {
        entry.line.destroy();
        return false;
    }

            return true;
        });

        // 2. verwijder het object zelf
        if (obj.konvaGroup) {
            obj.konvaGroup.destroy();
            //obj.konvaGroup.getLayer().draw();
        }

        // 3. leeg de tabel
        document.getElementById("objectInfo").innerHTML = "";
	// Hele tekening opnieuw laden
        window.redrawNetwork();
    })
        .catch(err => console.error("Delete failed:", err));
    });
    td.appendChild(btn);
    tr.appendChild(th);
    tr.appendChild(td);
    table.appendChild(tr);
}


function loadPageList() {
    return fetch("/api/pagelist")
        .then(r => r.text())
        .then(xmlText => {
            const parser = new DOMParser();
            const xml = parser.parseFromString(xmlText, "application/xml");
            const names = [...xml.getElementsByTagName("name")];
            return names.map(n => n.textContent.trim());
        });
}

function updatePageList(obj, action, page) {
    const payload = {
        item: obj.item,
        tbl: obj.tbl,
        action,
        page
    };

    fetch("/api/setpagelist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
    })
    .then(r => r.json())
    .then(data => {
        console.log("Pagelist updated:", data);

        // Update local object
        if (action === "add") {
            obj.pagelist.push(page);
        } else {
            obj.pagelist = obj.pagelist.filter(p => p !== page);
        }

        // Refresh the table
        fillObjectTable(obj);

        // Optional: update Konva visibility if page affects it
        //updateKonvaVisibility(obj);
	 window.redrawNetwork();
    })
    .catch(err => console.error("Pagelist update failed:", err));
}

