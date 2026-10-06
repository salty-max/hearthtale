CREATE TABLE "companion_links" (
	"id" serial PRIMARY KEY NOT NULL,
	"token_hash" text NOT NULL,
	"account_id" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_upload_at" timestamp with time zone,
	CONSTRAINT "companion_links_token_hash_unique" UNIQUE("token_hash")
);
--> statement-breakpoint
ALTER TABLE "companion_links" ADD CONSTRAINT "companion_links_account_id_accounts_id_fk" FOREIGN KEY ("account_id") REFERENCES "public"."accounts"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "companion_links_account" ON "companion_links" USING btree ("account_id");