<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

#[Fillable(['restriction_publication_id', 'jurisdiction_id', 'restriction_rule_version_id', 'previous_rule_version_id', 'action'])]
class RestrictionPublicationItem extends Model
{
    public function publication(): BelongsTo
    {
        return $this->belongsTo(RestrictionPublication::class, 'restriction_publication_id');
    }

    public function jurisdiction(): BelongsTo
    {
        return $this->belongsTo(Jurisdiction::class);
    }

    public function ruleVersion(): BelongsTo
    {
        return $this->belongsTo(RestrictionRuleVersion::class, 'restriction_rule_version_id');
    }

    public function previousRuleVersion(): BelongsTo
    {
        return $this->belongsTo(RestrictionRuleVersion::class, 'previous_rule_version_id');
    }
}
