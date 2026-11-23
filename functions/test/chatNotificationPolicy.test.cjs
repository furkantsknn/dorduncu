const assert = require("node:assert/strict");
const test = require("node:test");
const {
  chatNotificationContent,
  chatNotificationData,
  chatNotificationId,
  chatRecipientIds,
} = require("../lib/chat/notifyOnEventMessage.js");

test("chat recipients are unique and exclude sender", () => {
  assert.deepEqual(
    chatRecipientIds({olusturanUid: "owner", selectedPlayerIds: ["sender", "p2"], katilanlar: ["p2"]}, "sender"),
    ["owner", "p2"],
  );
});

test("chat routing keeps only the event id", () => {
  assert.deepEqual(chatNotificationData(" event-1 "), {eventId: "event-1"});
  assert.equal("messageId" in chatNotificationData("event-1"), false);
  assert.equal("senderUid" in chatNotificationData("event-1"), false);
});

test("chat notification text is private and localized", () => {
  assert.deepEqual(chatNotificationContent("tr"), {
    title: "Yeni mesaj", message: "Yeni bir mesajın var.",
  });
  assert.deepEqual(chatNotificationContent("en-US"), {
    title: "New message", message: "You have a new message.",
  });
  assert.deepEqual(chatNotificationContent("de"), {
    title: "Neue Nachricht", message: "Du hast eine neue Nachricht.",
  });
});

test("same message always uses the same notification id", () => {
  assert.equal(chatNotificationId("event-1", "message-1"), "chat_event-1_message-1");
  assert.equal(chatNotificationId("event-1", "message-1"), chatNotificationId("event-1", "message-1"));
});
