<?php

namespace App\Installation;

enum InstallationStage: string
{
    case New = 'new';
    case Configured = 'configured';
    case Migrated = 'migrated';
    case OperatorCreated = 'operator_created';
    case Completed = 'completed';
    case Failed = 'failed';
}
