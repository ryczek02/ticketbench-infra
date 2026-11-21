// Least-privilege application user: find/insert/update/remove on the
// benchmark database, no collection or index management (readWrite would
// allow dropCollection and createIndex).
const admin = db.getSiblingDB("admin");
admin.createRole({
  role: "tbDml",
  privileges: [{ resource: { db: "ticketbench", collection: "" }, actions: ["find", "insert", "update", "remove"] }],
  roles: [],
});
admin.createUser({ user: "tb_app", pwd: "tb_app", roles: [{ role: "tbDml", db: "admin" }] });
