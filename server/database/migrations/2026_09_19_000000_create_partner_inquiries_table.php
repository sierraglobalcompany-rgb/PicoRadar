<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('partner_inquiries', function (Blueprint $table): void {
            $table->id();
            $table->string('public_id', 27)->unique();
            $table->string('idempotency_hash', 64)->unique();
            $table->string('request_fingerprint', 64);
            $table->string('business_name', 120);
            $table->string('contact_name', 120);
            $table->string('email', 254);
            $table->string('phone', 24);
            $table->string('city', 120);
            $table->string('category', 32);
            $table->text('message')->nullable();
            $table->string('consent_version', 40);
            $table->timestamp('consented_at');
            $table->string('status', 24)->default('pending');
            $table->timestamps();

            $table->index(['status', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('partner_inquiries');
    }
};
