CREATE TABLE "removed" (
	"account_id" integer NOT NULL,
	"guid" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "removed_account_id_guid_pk" PRIMARY KEY("account_id","guid")
);
--> statement-breakpoint
ALTER TABLE "removed" ADD CONSTRAINT "removed_account_id_accounts_id_fk" FOREIGN KEY ("account_id") REFERENCES "public"."accounts"("id") ON DELETE cascade ON UPDATE no action;