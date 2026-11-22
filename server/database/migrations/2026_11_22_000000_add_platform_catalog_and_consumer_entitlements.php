<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('app_users', function (Blueprint $table): void {
            $table->string('account_plan', 16)->default('free')->index();
            $table->timestamp('plan_valid_from')->nullable();
            $table->timestamp('plan_valid_until')->nullable();
            $table->string('plan_source', 32)->nullable();
            $table->string('plan_reference', 120)->nullable();
            $table->string('account_status', 16)->default('active')->index();
            $table->text('status_reason')->nullable();
            $table->foreignId('status_changed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('status_changed_at')->nullable();
            $table->timestamp('status_until')->nullable();
        });

        Schema::create('service_providers', function (Blueprint $table): void {
            $table->id();
            $table->string('category', 32);
            $table->char('department_code', 2);
            $table->char('municipality_code', 5);
            $table->string('name', 160);
            $table->string('address', 240)->nullable();
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();
            $table->string('source_url', 768)->nullable();
            $table->string('contact_url', 768)->nullable();
            $table->timestamp('verified_at')->nullable();
            $table->date('valid_until')->nullable();
            $table->string('status', 20)->default('draft');
            $table->timestamps();
            $table->index(['category', 'municipality_code', 'status'], 'service_providers_directory');
            $table->index('source_url', 'service_providers_source');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('service_providers');

        Schema::table('app_users', function (Blueprint $table): void {
            $table->dropConstrainedForeignId('status_changed_by');
            $table->dropColumn([
                'account_plan', 'plan_valid_from', 'plan_valid_until', 'plan_source', 'plan_reference',
                'account_status', 'status_reason', 'status_changed_at', 'status_until',
            ]);
        });
    }
};
