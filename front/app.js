import { API_URL } from "./config.js";
import { api } from "./api.js";

const $ = (selector, root = document) => root.querySelector(selector);

$("#docs-link").href = API_URL;

const dateFormat = new Intl.DateTimeFormat("fr-FR", { dateStyle: "long" });
const formatDate = (iso) => dateFormat.format(new Date(iso));

const dateTimeFormat = new Intl.DateTimeFormat("fr-FR", {
  dateStyle: "medium",
  timeStyle: "short",
});
const formatDateTime = (iso) => dateTimeFormat.format(new Date(iso));

// Construit un élément sans jamais passer par innerHTML : les données de
// l'API (titres, noms) sont insérées comme du texte.
function el(tag, props = {}, ...children) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (key === "class") node.className = value;
    else if (key.startsWith("on")) node.addEventListener(key.slice(2), value);
    else node.setAttribute(key, value);
  }
  node.append(...children);
  return node;
}

function button(label, onClick, className = "") {
  return el(
    "button",
    { type: "button", class: className, onclick: onClick },
    label,
  );
}

function toast(message, isError = false) {
  const node = el("p", { class: isError ? "toast error" : "toast" }, message);
  $("#toasts").append(node);
  setTimeout(() => node.remove(), 5000);
}

// Exécute une action déclenchée par un bouton et affiche l'erreur de l'API.
async function run(action) {
  try {
    await action();
  } catch (error) {
    toast(error.message, true);
  }
}

function showFormError(dialog, error) {
  const target = $(".form-error", dialog);
  target.textContent = error ? error.message : "";
  target.hidden = !error;
}

for (const cancel of document.querySelectorAll("[data-cancel]")) {
  cancel.addEventListener("click", () => cancel.closest("dialog").close());
}

// Branche un formulaire de boîte de dialogue sur un appel à l'API.
// L'erreur renvoyée par l'API reste affichée dans la boîte, qui ne se ferme
// qu'en cas de succès.
function bindSubmit(dialog, form, handler) {
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    showFormError(dialog, null);
    try {
      await handler(new FormData(form));
      dialog.close();
      await refresh();
    } catch (error) {
      showFormError(dialog, error);
    }
  });
}

// overdue games ID

let overdueGameIDs = [];

// --- Onglets ---------------------------------------------------------------

const tabs = ["games", "members", "overdue-loans"];

function currentTab() {
  const name = location.hash.slice(1);
  return tabs.includes(name) ? name : "games";
}

async function refresh() {
  const tab = currentTab();
  for (const name of tabs) {
    $(`#${name}`).hidden = name !== tab;
    $(`[data-tab="${name}"]`).toggleAttribute("aria-current", name === tab);
  }
  if (tab === "games") {
    await run(() => {
      loadOverdueLoans(false);
    });
    await run(loadGames);
  } else if (tab === "members") {
    await run(() => {
      loadOverdueLoans(false);
    });
    await run(loadMembers);
  } else if (tab === "overdue-loans") {
    await run(loadOverdueLoans);
  }
}

window.addEventListener("hashchange", refresh);

// --- Jeux ------------------------------------------------------------------

async function loadGames() {
  const games = await api.listGames();
  $("#games-empty").hidden = games.length > 0;
  $("#games-list").replaceChildren(...games.map(gameCard));
}

function gameCard(game) {
  const isOverdue = overdueGameIDs.includes(game.id);

  const players =
    game.minPlayers === game.maxPlayers
      ? `${game.minPlayers}`
      : `${game.minPlayers} à ${game.maxPlayers}`;
  const status = game.isAvailable
    ? el("span", { class: "badge ok" }, "Disponible")
    : isOverdue
      ? el("span", { class: "badge late" }, "Emprunté [retard]")
      : el("span", { class: "badge busy" }, "Emprunté");

  const actions = el("div", { class: "actions" });

  actions.append(button("Modifier", () => openGameUpdateDialog(game)));

  if (game.isAvailable) {
    actions.append(
      button("Emprunter", () => openBorrowDialog(game), "primary"),
    );
  } else {
    actions.append(button("Rendre", () => openReturnGameDialog(game)));
  }

  actions.append(
    button("Supprimer", () => openGameDeleteDialog(game), "danger"),
  );

  return el(
    "li",
    { class: "card" },
    el("div", { class: "card-head" }, el("h3", {}, game.title), status),
    el(
      "p",
      { class: "meta" },
      `${players} joueur·ses · ${game.durationMinutes} min`,
    ),
    actions,
  );
}

const gameDialog = $("#game-dialog");
const gameForm = $("#game-form");

$("#add-game").addEventListener("click", () => {
  gameForm.reset();
  showFormError(gameDialog, null);
  gameDialog.showModal();
});

bindSubmit(gameDialog, gameForm, (data) =>
  api.createGame({
    title: data.get("title").trim(),
    minPlayers: Number(data.get("minPlayers")),
    maxPlayers: Number(data.get("maxPlayers")),
    durationMinutes: Number(data.get("durationMinutes")),
  }),
);

// --- Update Game

const gameUpdateDialog = $("#game-update-dialog");
const gameUpdateForm = $("#game-update-form");

let gameBeingUpdated = null;

function openGameUpdateDialog(game) {
  gameBeingUpdated = game;

  gameUpdateForm.reset();
  showFormError(gameUpdateDialog, null);
  gameUpdateDialog.showModal();

  const { title, minPlayers, maxPlayers, durationMinutes } =
    gameUpdateForm.elements;

  title.value = game.title;
  minPlayers.value = game.minPlayers;
  maxPlayers.value = game.maxPlayers;
  durationMinutes.value = game.durationMinutes;
}

bindSubmit(gameUpdateDialog, gameUpdateForm, (data) =>
  api.updateGame(gameBeingUpdated.id, {
    title: data.get("title").trim(),
    minPlayers: Number(data.get("minPlayers")),
    maxPlayers: Number(data.get("maxPlayers")),
    durationMinutes: Number(data.get("durationMinutes")),
  }),
);

// --- Delete Game
const gameConfirmationDialog = $("#game-confirmation-dialog");
const gameConfirmationForm = $("#game-confirmation-form");

let gameBeingDeleted = null;

function openGameDeleteDialog(game) {
  gameBeingDeleted = game;

  const title = $(".title", gameConfirmationForm);
  title.textContent = `Supprimer « ${game.title} »`;

  const message = $(".message", gameConfirmationForm);
  message.textContent = "Voulez-vous vraiment supprimer ce jeu ?";

  showFormError(gameConfirmationDialog, null);
  gameConfirmationDialog.showModal();
}

bindSubmit(gameConfirmationDialog, gameConfirmationForm, () =>
  api.deleteGame(gameBeingDeleted.id),
);

// --- Emprunts --------------------------------------------------------------

async function loadOverdueLoans(isOnPage = true) {
  // try-catch car overdueGameIDs est utilisé dans les tests.
  try {
    const loans = await api.listOverdueLoans();

    overdueGameIDs = loans.map((loan) => loan.gameID);

    $("header nav a[data-tab='overdue-loans']").textContent =
      `Emprunts en retard (${loans.length})`;

    if (isOnPage) {
      $("#overdue-loans .title").textContent =
        `Emprunts en retard (${loans.length})`;

      $("#overdue-loans-empty").hidden = loans.length > 0;

      const cards = await Promise.all(loans.map(overdueLoanRow));
      $("#overdue-loans-list").replaceChildren(...cards);
    }
  } catch {
    overdueGameIDs = [];

    $("header nav a[data-tab='overdue-loans']").textContent =
      `Emprunts en retard`;
  }
}

async function overdueLoanRow(loan) {
  const game = await api.showGame(loan.gameID);
  const member = await api.showMember(loan.memberID);

  const gameTitle = el("h3", { class: "gameTitle" }, game.title);
  const memberName = labelContentEl("Adhérent·e :", member.name);
  const dueAt = labelContentEl("Retour prévu :", formatDateTime(loan.dueAt));

  const diffTime = Math.abs(new Date(loan.dueAt) - new Date());
  const diffDays = Math.floor(diffTime / (1000 * 60 * 60 * 24));

  const overdueDate = labelContentEl(
    "Retard :",
    `${diffDays} ${diffDays > 1 ? "jours" : "jour"}`,
  );

  return el("li", { class: "card" }, gameTitle, memberName, dueAt, overdueDate);
}

const borrowDialog = $("#borrow-dialog");
const borrowForm = $("#borrow-form");
let borrowedGame = null;

async function openBorrowDialog(game) {
  await run(async () => {
    const members = await api.listMembers();
    if (members.length === 0) {
      toast("Ajoutez d'abord un·e adhérent·e pour pouvoir emprunter.", true);
      return;
    }
    borrowedGame = game;
    $("#borrow-dialog-title").textContent = `Emprunter « ${game.title} »`;
    $("select", borrowForm).replaceChildren(
      ...members.map((member) =>
        el("option", { value: member.id }, `${member.name} (${member.email})`),
      ),
    );
    showFormError(borrowDialog, null);
    borrowDialog.showModal();
  });
}

bindSubmit(borrowDialog, borrowForm, async (data) => {
  const loan = await api.borrow(borrowedGame.id, data.get("memberID"));
  toast(
    `« ${borrowedGame.title} » emprunté, à rendre avant le ${formatDate(loan.dueAt)}.`,
  );
});

// --- Return Game

const returnGameConfirmationDialog = $("#return-game-confirmation-dialog");
const returnGameConfirmationForm = $("#return-game-confirmation-form");

let gameBeingReturned = null;

function openReturnGameDialog(game) {
  gameBeingReturned = game;

  const title = $(".title", returnGameConfirmationForm);
  title.textContent = `Rendre « ${game.title} »`;

  const message = $(".message", returnGameConfirmationForm);
  message.textContent = "Voulez-vous vraiment rendre ce jeu ?";

  showFormError(returnGameConfirmationDialog, null);
  returnGameConfirmationDialog.showModal();
}

bindSubmit(returnGameConfirmationDialog, returnGameConfirmationForm, () =>
  returnGame(gameBeingReturned),
);

// --- Member Loans

const memberLoansDialog = $("#member-loans-dialog");

async function openMemberLoansDialog(member) {
  await run(async () => {
    $(".title", memberLoansDialog).textContent =
      `Liste des emprunts de « ${member.name} »`;

    loadLoansOf(member.id);

    memberLoansDialog.showModal();
  });
}

async function loadLoansOf(memberID) {
  const loans = await api.listLoansOfMember(memberID);
  const rows = await Promise.all(loans.map(memberLoanRow));
  $("#member-loans-empty").hidden = loans.length > 0;
  $("#member-loans-list").replaceChildren(...rows);
}

async function memberLoanRow(loan) {
  const game = await api.showGame(loan.gameID);

  const gameTitle = el("h3", { class: "gameTitle" }, game.title);
  const borrowedAt = labelContentEl(
    "Date d'emprunts :",
    formatDateTime(loan.borrowedAt),
  );
  const dueAt = labelContentEl("Retour prévu :", formatDateTime(loan.dueAt));

  const loanState = loan.returnedAt
    ? "Rendu"
    : new Date(loan.dueAt).getTime() > new Date().getTime()
      ? "En cours"
      : "En retard";

  const state = labelContentEl("État :", loanState);

  return el("li", { class: "loanRow" }, gameTitle, borrowedAt, dueAt, state);
}

function labelContentEl(label, content) {
  const labelEl = el("span", { class: "label" }, label);
  const contentEl = el("span", { class: "content" }, content);

  return el("div", { class: "labelContent" }, labelEl, contentEl);
}

// --- Adhérent·es -----------------------------------------------------------

async function loadMembers() {
  const members = await api.listMembers();
  $("#members-empty").hidden = members.length > 0;
  $("#members-list").replaceChildren(...members.map(memberRow));
}

function memberRow(member) {
  const actions = el("div", { class: "actions" });

  actions.append(button("Emprunts", () => openMemberLoansDialog(member)));

  actions.append(button("Modifier", () => openMemberUpdateDialog(member)));
  actions.append(
    button("Supprimer", () => openMemberDeleteDialog(member), "danger"),
  );

  return el(
    "li",
    { class: "row" },
    el(
      "div",
      { class: "row-main" },
      el("p", {}, el("strong", {}, member.name)),
      el("p", { class: "meta" }, member.email),
    ),
    actions,
  );
}

const memberDialog = $("#member-dialog");
const memberForm = $("#member-form");

$("#add-member").addEventListener("click", () => {
  memberForm.reset();
  showFormError(memberDialog, null);
  memberDialog.showModal();
});

bindSubmit(memberDialog, memberForm, (data) =>
  api.createMember({
    name: data.get("name").trim(),
    email: data.get("email").trim(),
  }),
);

refresh();

// --- Update Member

const memberUpdateDialog = $("#member-update-dialog");
const memberUpdateForm = $("#member-update-form");

let memberBeingUpdated = null;

function openMemberUpdateDialog(member) {
  memberBeingUpdated = member;

  memberUpdateForm.reset();
  showFormError(memberUpdateDialog, null);
  memberUpdateDialog.showModal();

  const { name, email } = memberUpdateForm.elements;

  name.value = member.name;
  email.value = member.email;
}

bindSubmit(memberUpdateDialog, memberUpdateForm, (data) =>
  api.updateMember(memberBeingUpdated.id, {
    name: data.get("name").trim(),
    email: data.get("email").trim(),
  }),
);

// --- Delete Member

const memberConfirmationDialog = $("#member-confirmation-dialog");
const memberConfirmationForm = $("#member-confirmation-form");

let memberBeingDeleted = null;

function openMemberDeleteDialog(member) {
  memberBeingDeleted = member;

  const title = $(".title", memberConfirmationForm);
  title.textContent = `Supprimer « ${member.name} »`;

  const message = $(".message", memberConfirmationForm);
  message.textContent = "Voulez-vous vraiment supprimer cet·te adhérent·e ?";

  showFormError(memberConfirmationDialog, null);
  memberConfirmationDialog.showModal();
}

bindSubmit(memberConfirmationDialog, memberConfirmationForm, () =>
  api.deleteMember(memberBeingDeleted.id),
);

// --- Helpers

async function getCurrentLoanID(gameID) {
  const members = await api.listMembers();

  const memberIDs = members.map((m) => m.id);

  const loansByMember = await Promise.all(
    memberIDs.map((id) => {
      return api.listLoansOfMember(id);
    }),
  );

  return loansByMember
    .flatMap((item) => item)
    .find((item) => item.gameID === gameID && !item.returnedAt)?.id;
}

async function returnGame(game) {
  const loanID = await getCurrentLoanID(game.id);

  if (!!loanID) {
    await api.returnGame(loanID);

    toast(`« ${game.title} » vient d'être rendu`);
  }
}
