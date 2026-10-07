const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const contentPath = path.join(root, "marketing", "social", "30_day_content_calendar.csv");
const manifestPath = path.join(root, "public", "social", "2026-10", "index.json");
const outputPath = path.join(root, "marketing", "social", "Dort_Metricool_30_Gun_READY.csv");

const templateCandidates = [
  path.join(root, "marketing", "social", "metricool_template.csv"),
  path.join(root, "marketing", "social", "metricool_template.csv.csv"),
];

const networkColumns = [
  "Facebook",
  "Twitter/X",
  "LinkedIn",
  "GBP",
  "Instagram",
  "Pinterest",
  "TikTok",
  "Youtube",
  "YouTube",
  "Threads",
  "Bluesky",
];

function readText(filePath) {
  return fs.readFileSync(filePath, "utf8").replace(/^\uFEFF/, "");
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = "";
  let inQuotes = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];

    if (inQuotes) {
      if (char === "\"") {
        if (text[index + 1] === "\"") {
          field += "\"";
          index += 1;
        } else {
          inQuotes = false;
        }
      } else {
        field += char;
      }
      continue;
    }

    if (char === "\"") {
      inQuotes = true;
    } else if (char === ",") {
      row.push(field);
      field = "";
    } else if (char === "\n") {
      row.push(field);
      rows.push(row);
      row = [];
      field = "";
    } else if (char !== "\r") {
      field += char;
    }
  }

  if (field.length > 0 || row.length > 0) {
    row.push(field);
    rows.push(row);
  }

  return rows.filter((item) => item.some((value) => value.trim() !== ""));
}

function quoteCsv(value) {
  const text = String(value ?? "");
  if (/[",\n\r]/.test(text)) {
    return `"${text.replace(/"/g, "\"\"")}"`;
  }
  return text;
}

function resolveTemplatePath() {
  const found = templateCandidates.find((candidate) => fs.existsSync(candidate));
  if (!found) {
    throw new Error("Metricool şablonu bulunamadı.");
  }
  return found;
}

function dateForDay(day) {
  const date = new Date(Date.UTC(2026, 9, 6));
  date.setUTCDate(date.getUTCDate() + (day - 1));
  const month = String(date.getUTCMonth() + 1).padStart(2, "0");
  const dayOfMonth = String(date.getUTCDate()).padStart(2, "0");
  return `${date.getUTCFullYear()}-${month}-${dayOfMonth}`;
}

function postText(row) {
  const body = (row.uzun_caption || row.kisa_caption || "").trim();
  const callToAction = (row.cta || "").trim();
  const hashtags = (row.hashtag_seti || "").trim();
  return [body, callToAction, hashtags].filter(Boolean).join("\n\n");
}

function main() {
  const templatePath = resolveTemplatePath();
  const templateRows = parseCsv(readText(templatePath));
  const headers = templateRows[0].map((header) => header.trim());
  const contentRows = parseCsv(readText(contentPath));
  const contentHeaders = contentRows[0];
  const manifest = JSON.parse(readText(manifestPath));
  const urls = new Map(
    manifest.map((item) => [Number(item.day), String(item.publicUrl)]),
  );

  const posts = new Map();
  for (const values of contentRows.slice(1)) {
    const record = {};
    contentHeaders.forEach((header, index) => {
      record[header] = values[index] || "";
    });
    posts.set(Number(record.gun), record);
  }

  if (posts.size !== 30 || urls.size !== 30) {
    throw new Error("İçerik ve manifest tam 30 gün olmalı.");
  }

  const column = (name) => {
    const index = headers.indexOf(name);
    if (index === -1) {
      throw new Error(`Şablonda sütun yok: ${name}`);
    }
    return index;
  };

  const textIndex = column("Text");
  const dateIndex = column("Date");
  const timeIndex = column("Time");
  const draftIndex = column("Draft");
  const pictureIndex = column("Picture Url 1");
  const instagramIndex = column("Instagram");
  const tiktokIndex = column("TikTok");
  const twitterIndex = column("Twitter/X");
  const instagramTypeIndex = column("Instagram Post Type");
  const networkIndexes = networkColumns
    .map((name) => headers.indexOf(name))
    .filter((index) => index >= 0);

  const output = [headers.map(quoteCsv).join(",")];

  for (let day = 1; day <= 30; day += 1) {
    const post = posts.get(day);
    const publicUrl = urls.get(day);
    if (!post || !publicUrl) {
      throw new Error(`Gün ${day} eşleşmedi.`);
    }

    const row = headers.map(() => "");
    row[textIndex] = postText(post);
    row[dateIndex] = dateForDay(day);
    row[timeIndex] = "20:30:00";
    row[draftIndex] = "FALSE";
    row[pictureIndex] = publicUrl;
    networkIndexes.forEach((index) => {
      row[index] = "FALSE";
    });
    row[instagramIndex] = "TRUE";
    row[tiktokIndex] = "TRUE";
    row[twitterIndex] = "FALSE";
    row[instagramTypeIndex] = "POST";
    output.push(row.map(quoteCsv).join(","));
  }

  fs.writeFileSync(outputPath, `\uFEFF${output.join("\n")}\n`, "utf8");
  console.log("READY CSV CREATED");
}

main();
