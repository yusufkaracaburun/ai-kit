<?php
// Provider that trips L10.

namespace App\Providers;

use Illuminate\Foundation\Support\Providers\AuthServiceProvider as ServiceProvider;

class AuthServiceProvider extends ServiceProvider
{
    // L10: Missing Policy on Eloquent model with public-facing routes (🟠).
    protected $policies = [];
}
