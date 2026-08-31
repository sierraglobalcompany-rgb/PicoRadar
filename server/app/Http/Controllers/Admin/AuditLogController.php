<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

class AuditLogController extends Controller
{
    public function index(Request $request)
    {
        Gate::authorize('datasets.view');

        return view('admin.audit.index', [
            'operator' => $request->user(),
            'logs' => AuditLog::query()->with('actor')->latest('id')->paginate(50),
        ]);
    }
}
