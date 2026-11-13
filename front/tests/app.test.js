import {
  assertEqual,
  assertIncludes,
  assertTrue,
  test,
  waitFor,
} from "./runner.js";
import { mountApp } from "./helpers.js";

const catan = {
  id: "g1",
  title: "Catan",
  minPlayers: 3,
  maxPlayers: 4,
  durationMinutes: 90,
  isAvailable: true,
};
const dixit = {
  id: "g2",
  title: "Dixit",
  minPlayers: 3,
  maxPlayers: 6,
  durationMinutes: 30,
  isAvailable: false,
};
const camille = { id: "m1", name: "Camille", email: "camille@example.com" };

const cardOf = (app, title) =>
  app
    .$$("#games-list .card")
    .find((card) => card.querySelector("h3").textContent === title);

// Remplace toute suite d'espaces ou de retours à la ligne par un seul espace,
// comme le fait l'affichage dans le navigateur.
// car Prettier reformate le HTML
const textOf = (node) => node.textContent.replace(/\s+/g, " ").trim();

// --- Jeux

test("games list shows one card per game with its availability", async () => {
  const app = await mountApp({ "GET /games": [catan, dixit] });
  await waitFor(
    () => app.$$("#games-list .card").length === 2,
    "deux cartes de jeu",
  );
  assertIncludes(cardOf(app, "Catan").textContent, "Disponible");
  assertIncludes(cardOf(app, "Dixit").textContent, "Emprunté");
  assertIncludes(cardOf(app, "Catan").textContent, "3 à 4 joueur·ses · 90 min");
});

test("only an available game offers Borrow", async () => {
  const app = await mountApp({ "GET /games": [catan, dixit] });
  await waitFor(() => app.$$("#games-list .card").length === 2);
  const labels = (title) =>
    [...cardOf(app, title).querySelectorAll("button")].map(
      (button) => button.textContent,
    );
  assertTrue(
    labels("Catan").includes("Emprunter"),
    "Catan devrait proposer Emprunter",
  );
  assertTrue(
    !labels("Dixit").includes("Emprunter"),
    "Dixit est emprunté, il ne doit pas proposer Emprunter",
  );
});

test("with no game, a message invites to add one", async () => {
  const app = await mountApp({ "GET /games": [] });
  await waitFor(() => !app.$("#games-empty").hidden);
  assertIncludes(textOf(app.$("#games-empty")), "ne contient aucun jeu");
  assertIncludes(textOf(app.$("#games-empty")), "Ajouter un jeu");
});

test("adding a game posts the form then reloads the list", async () => {
  const app = await mountApp({
    "GET /games": [catan],
    "POST /games": [201, { ...catan, id: "g3", title: "Dixit" }],
  });
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.click("Ajouter un jeu");
  const form = app.$("#game-form");
  form.elements.title.value = "  Dixit ";
  form.elements.minPlayers.value = "3";
  form.elements.maxPlayers.value = "6";
  form.elements.durationMinutes.value = "30";
  form.requestSubmit();
  await waitFor(
    () =>
      app.calls.some(
        (call) => call.method === "POST" && call.path === "/games",
      ),
    "l'appel POST /games",
  );
  assertEqual(app.calls.find((call) => call.method === "POST").body, {
    title: "Dixit",
    minPlayers: 3,
    maxPlayers: 6,
    durationMinutes: 30,
  });
  await waitFor(() => !app.$("#game-dialog").open, "la boîte se ferme");
});

test("a validation error is shown in French and the dialog stays open", async () => {
  const app = await mountApp({
    "GET /games": [],
    "POST /games": [
      400,
      {
        error: true,
        reason: "title is empty, durationMinutes is less than minimum of 1",
      },
    ],
  });
  await waitFor(() => !app.$("#games-empty").hidden, "la page est chargée");
  app.click("Ajouter un jeu");
  app.$("#game-form").requestSubmit();
  await waitFor(
    () => !app.$("#game-dialog .form-error").hidden,
    "le message d'erreur",
  );
  assertEqual(
    app.$("#game-dialog .form-error").textContent,
    "Le titre est obligatoire. La durée doit être d'au moins 1.",
  );
  assertTrue(app.$("#game-dialog").open, "la boîte devrait rester ouverte");
});

test("updating a game sends the form then reloads the list", async () => {
  let games = [catan];
  const updated = {
    ...catan,
    title: "Lorem",
    minPlayers: 7,
    maxPlayers: 9,
    durationMinutes: 35,
  };
  const app = await mountApp({
    "GET /games": () => [200, games],
    "PUT /games/g1": () => {
      games = [updated];
      return [200, updated];
    },
  });
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.click("Modifier");
  const form = app.$("#game-update-form");
  form.elements.title.value = "  Lorem ";
  form.elements.minPlayers.value = "7";
  form.elements.maxPlayers.value = "9";
  form.elements.durationMinutes.value = "35";
  form.requestSubmit();
  await waitFor(
    () =>
      app.calls.some(
        (call) => call.method === "PUT" && call.path === "/games/g1",
      ),
    "l'appel PUT /games/g1",
  );
  assertEqual(app.calls.find((call) => call.method === "PUT").body, {
    title: "Lorem",
    minPlayers: 7,
    maxPlayers: 9,
    durationMinutes: 35,
  });
  await waitFor(() => !app.$("#game-update-dialog").open, "la boîte se ferme");
  await waitFor(
    () => app.$("#games-list .card").textContent.includes("Lorem"),
    "la carte affiche le nouveau titre après rechargement",
  );
});

test("updating a game, a validation error is shown in French and the dialog stays open", async () => {
  const app = await mountApp({
    "GET /games": [catan],
    "PUT /games/g1": [
      400,
      {
        error: true,
        reason: "title is empty, durationMinutes is less than minimum of 1",
      },
    ],
  });
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.click("Modifier");
  const form = app.$("#game-update-form");
  form.requestSubmit();
  await waitFor(
    () => !app.$("#game-update-dialog .form-error").hidden,
    "le message d'erreur",
  );
  assertEqual(
    app.$("#game-update-dialog .form-error").textContent,
    "Le titre est obligatoire. La durée doit être d'au moins 1.",
  );
  assertTrue(
    app.$("#game-update-dialog").open,
    "la boîte devrait rester ouverte",
  );
});

test("deleting a game remove it then reloads the list", async () => {
  let games = [catan];
  const app = await mountApp({
    "GET /games": () => [200, games],
    "DELETE /games/g1": () => {
      games = [];
      return [204];
    },
  });
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.click("Supprimer");
  const form = app.$("#game-confirmation-form");
  form.requestSubmit();
  await waitFor(
    () =>
      app.calls.some(
        (call) => call.method === "DELETE" && call.path === "/games/g1",
      ),
    "l'appel DELETE /games/g1",
  );
  await waitFor(
    () => !app.$("#game-confirmation-dialog").open,
    "la boîte se ferme",
  );
  await waitFor(() => app.$$("#games-list .card").length === 0);
});

test("deleting a game that no longer exists shows an error in French and the dialog stays open", async () => {
  const app = await mountApp({
    "GET /games": [catan],
    "DELETE /games/g1": [
      404,
      {
        error: true,
        reason: "Game not found",
      },
    ],
  });
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.click("Supprimer");
  const form = app.$("#game-confirmation-form");
  form.requestSubmit();
  await waitFor(
    () => !app.$("#game-confirmation-dialog .form-error").hidden,
    "le message d'erreur",
  );
  assertEqual(
    app.$("#game-confirmation-dialog .form-error").textContent,
    "Ce jeu n'existe pas ou a déjà été supprimé.",
  );
  assertTrue(
    app.$("#game-confirmation-dialog").open,
    "la boîte devrait rester ouverte",
  );
});

// --- Emprunts

test("borrowing a game sends the game and the chosen member", async () => {
  const app = await mountApp({
    "GET /games": [catan],
    "GET /members": [camille],
    "POST /loans": [
      201,
      {
        id: "l1",
        gameID: "g1",
        memberID: "m1",
        borrowedAt: new Date().toISOString(),
        dueAt: new Date().toISOString(),
      },
    ],
  });
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.click("Emprunter", cardOf(app, "Catan"));
  await waitFor(() => app.$("#borrow-dialog").open, "la boîte d'emprunt");
  app.$("#borrow-form").requestSubmit();
  await waitFor(
    () =>
      app.calls.some(
        (call) => call.method === "POST" && call.path === "/loans",
      ),
    "l'appel POST /loans",
  );
  assertEqual(app.calls.find((call) => call.path === "/loans").body, {
    gameID: "g1",
    memberID: "m1",
  });
  await waitFor(
    () => app.$("#toasts").textContent.includes("emprunté"),
    "le message de confirmation",
  );
});

test("borrowing without any member explains that one must be added first", async () => {
  const app = await mountApp({ "GET /games": [catan], "GET /members": [] });
  await waitFor(() => app.$$("#games-list .card").length === 1);
  app.click("Emprunter", cardOf(app, "Catan"));
  await waitFor(
    () => app.$("#toasts").textContent.includes("Ajoutez d'abord"),
    "le message d'aide",
  );
  assertTrue(
    !app.$("#borrow-dialog").open,
    "la boîte d'emprunt ne doit pas s'ouvrir",
  );
});

// --- Adhérent·es

test("members tab lists the members", async () => {
  const app = await mountApp(
    { "GET /members": [camille] },
    { hash: "#members" },
  );
  await waitFor(() => app.$$("#members-list .row").length === 1);
  assertIncludes(app.$("#members-list .row").textContent, "Camille");
  assertIncludes(
    app.$("#members-list .row").textContent,
    "camille@example.com",
  );
});

test("with no member, a message invites to add one", async () => {
  const app = await mountApp({ "GET /members": [] }, { hash: "#members" });
  await waitFor(() => !app.$("#members-empty").hidden);
  assertIncludes(textOf(app.$("#members-empty")), "Ajouter un·e adhérent·e");
});

test("adding a member posts the form", async () => {
  const app = await mountApp(
    { "GET /members": [], "POST /members": [201, camille] },
    { hash: "#members" },
  );
  await waitFor(() => !app.$("#members-empty").hidden);
  app.click("Ajouter un·e adhérent·e");
  const form = app.$("#member-form");
  form.elements.name.value = " Camille ";
  form.elements.email.value = "camille@example.com";
  form.requestSubmit();
  await waitFor(
    () =>
      app.calls.some(
        (call) => call.method === "POST" && call.path === "/members",
      ),
    "l'appel POST /members",
  );
  assertEqual(app.calls.find((call) => call.method === "POST").body, {
    name: "Camille",
    email: "camille@example.com",
  });
});

test("an email already in use is shown in French", async () => {
  const app = await mountApp(
    {
      "GET /members": [],
      "POST /members": [
        409,
        { error: true, reason: "A member with this email already exists" },
      ],
    },
    { hash: "#members" },
  );
  await waitFor(() => !app.$("#members-empty").hidden);
  app.click("Ajouter un·e adhérent·e");
  app.$("#member-form").requestSubmit();
  await waitFor(
    () => !app.$("#member-dialog .form-error").hidden,
    "le message d'erreur",
  );
  assertIncludes(
    app.$("#member-dialog .form-error").textContent,
    "utilise déjà cette adresse e-mail",
  );
});

test("createMember, a validation error is shown in French and the dialog stays open", async () => {
  const app = await mountApp(
    {
      "GET /members": [],
      "POST /members": [
        400,
        {
          error: true,
          reason: "name is empty, email is not a valid email address",
        },
      ],
    },
    { hash: "#members" },
  );
  await waitFor(() => !app.$("#members-empty").hidden, "la page est chargée");
  app.click("Ajouter un·e adhérent·e");
  app.$("#member-form").requestSubmit();
  await waitFor(
    () => !app.$("#member-dialog .form-error").hidden,
    "le message d'erreur",
  );
  assertEqual(
    app.$("#member-dialog .form-error").textContent,
    "Le nom est obligatoire. L'adresse e-mail n'est pas valide (exemple : nom@example.com).",
  );
  assertTrue(app.$("#member-dialog").open, "la boîte devrait rester ouverte");
});

test("updating a member sends the form then reloads the list", async () => {
  let members = [camille];
  const updated = {
    ...camille,
    name: "Camille Liones",
    email: "camille@lion.es",
  };
  const app = await mountApp(
    {
      "GET /members": () => [200, members],
      "PUT /members/m1": () => {
        members = [updated];
        return [200, updated];
      },
    },
    { hash: "#members" },
  );
  await waitFor(
    () => app.$$("#members-list .row").length === 1,
    "la liste des adhérent·es est chargée",
  );
  app.click("Modifier");
  const form = app.$("#member-update-form");
  form.elements.name.value = "  Camille Liones ";
  form.elements.email.value = "camille@lion.es";
  form.requestSubmit();
  await waitFor(
    () =>
      app.calls.some(
        (call) => call.method === "PUT" && call.path === "/members/m1",
      ),
    "l'appel PUT /members/m1",
  );
  assertEqual(app.calls.find((call) => call.method === "PUT").body, {
    name: "Camille Liones",
    email: "camille@lion.es",
  });
  await waitFor(
    () => !app.$("#member-update-dialog").open,
    "la boîte se ferme",
  );
  await waitFor(() => {
    const text = app.$("#members-list .row").textContent;
    return text.includes("Camille Liones") && text.includes("camille@lion.es");
  }, "la ligne affiche le nouveau nom et le nouveau courriel après rechargement");
});

test("updating a member, a validation error is shown in French and the dialog stays open", async () => {
  const app = await mountApp(
    {
      "GET /members": [camille],
      "PUT /members/m1": [
        400,
        {
          error: true,
          reason: "name is empty, email is not a valid email address",
        },
      ],
    },
    { hash: "#members" },
  );
  await waitFor(
    () => app.$$("#members-list .row").length === 1,
    "la liste des adhérent·es est chargée",
  );
  app.click("Modifier");
  const form = app.$("#member-update-form");
  form.requestSubmit();
  await waitFor(
    () => !app.$("#member-update-dialog .form-error").hidden,
    "le message d'erreur",
  );
  assertEqual(
    app.$("#member-update-dialog .form-error").textContent,
    "Le nom est obligatoire. L'adresse e-mail n'est pas valide (exemple : nom@example.com).",
  );
  assertTrue(
    app.$("#member-update-dialog").open,
    "la boîte devrait rester ouverte",
  );
});

test("deleting a member remove it then reloads the list", async () => {
  let members = [camille];
  const app = await mountApp(
    {
      "GET /members": () => [200, members],
      "DELETE /members/m1": () => {
        members = [];
        return [204];
      },
    },
    { hash: "#members" },
  );
  await waitFor(
    () => app.$$("#members-list .row").length === 1,
    "la liste des adhérent·es est chargée",
  );
  app.click("Supprimer");
  const form = app.$("#member-confirmation-form");
  form.requestSubmit();
  await waitFor(
    () =>
      app.calls.some(
        (call) => call.method === "DELETE" && call.path === "/members/m1",
      ),
    "l'appel DELETE /members/m1",
  );
  await waitFor(
    () => !app.$("#member-confirmation-dialog").open,
    "la boîte se ferme",
  );
  await waitFor(
    () => app.$$("#members-list .row").length === 0,
    "la liste des adhérent·es est chargée",
  );
});

test("deleting a member that no longer exists shows an error in French and the dialog stays open", async () => {
  const app = await mountApp(
    {
      "GET /members": [camille],
      "DELETE /members/m1": [
        404,
        {
          error: true,
          reason: "Member not found",
        },
      ],
    },
    { hash: "#members" },
  );
  await waitFor(
    () => app.$$("#members-list .row").length === 1,
    "la liste des adhérent·es est chargée",
  );
  app.click("Supprimer");
  const form = app.$("#member-confirmation-form");
  form.requestSubmit();
  await waitFor(
    () => !app.$("#member-confirmation-dialog .form-error").hidden,
    "le message d'erreur",
  );
  assertEqual(
    app.$("#member-confirmation-dialog .form-error").textContent,
    "Cet·te adhérent·e n'existe pas ou a déjà été supprimé·e.",
  );
  assertTrue(
    app.$("#member-confirmation-dialog").open,
    "la boîte devrait rester ouverte",
  );
});
