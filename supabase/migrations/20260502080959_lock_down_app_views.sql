begin;

revoke all on
  public.app_doc_today,
  public.app_coach_today,
  public.app_manager_today,
  public.app_pipeline_board,
  public.app_team_roster_summary,
  public.app_document_queue
from anon, public;

grant select on
  public.app_doc_today,
  public.app_coach_today,
  public.app_manager_today,
  public.app_pipeline_board,
  public.app_team_roster_summary,
  public.app_document_queue
to authenticated, service_role;

commit;
