@extends('layouts.admin',['title'=>'Campana | PicoRadar'])
@section('content')
<h1 class="text-3xl font-semibold">{{$campaign->exists?'Editar':'Nueva'}} campana</h1>
@if($errors->any())<p class="mt-4 rounded border border-red-200 bg-red-50 p-3 text-red-800">{{$errors->first()}}</p>@endif
<form class="mt-6 grid max-w-4xl gap-4 rounded border bg-white p-5" method="POST" enctype="multipart/form-data" action="{{$action}}">@csrf @if($method==='PUT')@method('PUT')@endif
<label>Patrocinador<select required name="sponsor_id">@foreach($sponsors as $sponsor)<option value="{{$sponsor->id}}" @selected((string)old('sponsor_id',$campaign->sponsor_id)===(string)$sponsor->id)>{{$sponsor->name}}</option>@endforeach</select></label>
<label>Etiqueta<input required maxlength="80" name="eyebrow" value="{{old('eyebrow',$campaign->eyebrow ?? 'PATROCINADO')}}"></label>
<label>Titulo<input required maxlength="120" name="title" value="{{old('title',$campaign->title)}}"></label>
<label>Subtitulo<textarea required maxlength="240" name="subtitle">{{old('subtitle',$campaign->subtitle)}}</textarea></label>
<div class="grid gap-4 md:grid-cols-2"><label>Texto CTA<input required maxlength="64" name="cta_text" value="{{old('cta_text',$campaign->cta_text)}}"></label><label>Destino HTTPS<input required maxlength="2048" type="url" name="cta_url" value="{{old('cta_url',$campaign->cta_url)}}"></label></div>
<input type="hidden" name="placement" value="{{config('campaigns.placement')}}">
<div class="grid gap-4 md:grid-cols-2"><label>Prioridad<input required min="0" max="1000" type="number" name="priority" value="{{old('priority',$campaign->priority ?? 100)}}"></label><label>Alcance<select required name="scope">@foreach(\App\Enums\CampaignScope::cases() as $scope)<option value="{{$scope->value}}" @selected(old('scope',$campaign->scope?->value ?? 'national')===$scope->value)>{{$scope->value}}</option>@endforeach</select></label></div>
<label>Unidad territorial<select name="geographic_unit_id"><option value="">Nacional</option>@foreach($geographicUnits as $unit)<option value="{{$unit->id}}" @selected((string)old('geographic_unit_id',$campaign->geographic_unit_id)===(string)$unit->id)>{{$unit->level->value}} - {{$unit->name}} ({{$unit->code}})</option>@endforeach</select></label>
<div class="grid gap-4 md:grid-cols-2"><label>Inicio<input required type="datetime-local" name="starts_at" value="{{old('starts_at',$campaign->starts_at?->format('Y-m-d\TH:i'))}}"></label><label>Fin<input required type="datetime-local" name="ends_at" value="{{old('ends_at',$campaign->ends_at?->format('Y-m-d\TH:i'))}}"></label></div>
<label>Imagen C11 @if($campaign->exists)<span class="text-sm text-slate-500">(opcional para conservar la actual)</span>@endif<input @required(!$campaign->exists) accept="image/jpeg,image/png,image/webp" type="file" name="image"></label>
<div><button class="rounded bg-slate-900 px-4 py-2 text-white">Guardar borrador</button></div>
</form>
@endsection
