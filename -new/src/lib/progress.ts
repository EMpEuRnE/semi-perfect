import "server-only";
import { createClient } from "@/lib/supabase/server";
import { bangkokDay } from "@/lib/mission-rounds";
import type { Mission, UserMission, QueryState } from "@/lib/missions/data";
export type ProgressItem={id:string;type:"mission"|"challenge";title:string;href:string;state:"active"|"pending"|"completed"|"closed";approved:number;pending:number;target:number;unit:string;points:number;day:string|null;note:string|null};
export async function getProgressData(userId:string):Promise<QueryState<ProgressItem[]>> {
 try {
  const db=await createClient();
  const [rounds,participants]=await Promise.all([
   db.from("user_missions").select("id,mission_id,status,progress_value,participation_date,mission_snapshot").eq("user_id",userId).order("joined_at",{ascending:false}).limit(50),
   db.from("challenge_participants").select("id,challenge_id,status,progress_value").eq("user_id",userId).order("joined_at",{ascending:false}).limit(50)]);
  if(rounds.error||participants.error)return {status:"error"};
  const missionIds=[...new Set(rounds.data?.map(r=>r.mission_id)??[])],challengeIds=[...new Set(participants.data?.map(r=>r.challenge_id)??[])],roundIds=rounds.data?.map(r=>r.id)??[];
  const [missions,challenges,totals,activities,pendingActivities]=await Promise.all([
   missionIds.length?db.from("missions").select("id,title,target_value,target_unit,points,status,ends_at").in("id",missionIds):{data:[],error:null},
   challengeIds.length?db.from("challenges").select("id,title,target_value,target_unit,reward_points,status,ends_at").in("id",challengeIds):{data:[],error:null},
   roundIds.length?db.from("mission_activity_totals").select("user_mission_id,pending_value").in("user_mission_id",roundIds):{data:[],error:null},
   db.from("activities").select("user_mission_id,challenge_participant_id,value,verification_status,reviewer_note").eq("user_id",userId).order("created_at",{ascending:false}).limit(200),
   participants.data?.length?db.from("activities").select("challenge_participant_id,value").eq("user_id",userId).eq("verification_status","pending").in("challenge_participant_id",participants.data.map(p=>p.id)):{data:[],error:null}]);
  if([missions,challenges,totals,activities,pendingActivities].some(r=>r.error))return {status:"error"};
  const result:ProgressItem[]=[];const today=bangkokDay();
  for(const raw of rounds.data??[]) {
   const round=raw as unknown as UserMission;const live=missions.data?.find(m=>m.id===round.mission_id);
   const mission=round.mission_snapshot??live as Mission|undefined;if(!mission)continue;
   const pending=Number(totals.data?.find(t=>t.user_mission_id===round.id)?.pending_value??0);
   const latest=activities.data?.find(a=>a.user_mission_id===round.id);
   const closed=["cancelled","expired"].includes(round.status)||!!(round.participation_date&&round.participation_date<today)||!!(live?.ends_at&&new Date(live.ends_at).getTime()<Date.now());
   result.push({id:round.id,type:"mission",title:mission.title,href:`/missions/${round.mission_id}${round.participation_date?`?day=${round.participation_date}`:""}`,state:round.status==="completed"?"completed":pending>0?"pending":closed?"closed":"active",approved:Number(round.progress_value),pending,target:Number(mission.target_value),unit:mission.target_unit,points:mission.points,day:round.participation_date,note:latest?.verification_status==="rejected"?latest.reviewer_note:null});
  }
  for(const round of participants.data??[]) {
   const challenge=challenges.data?.find(c=>c.id===round.challenge_id);if(!challenge)continue;
   const latest=activities.data?.find(a=>a.challenge_participant_id===round.id);
   const pending=Number(pendingActivities.data?.find(a=>a.challenge_participant_id===round.id)?.value??0);
   const closed=["cancelled","disqualified"].includes(round.status)||["completed","cancelled"].includes(challenge.status)||!!(challenge.ends_at&&new Date(challenge.ends_at).getTime()<Date.now());
   result.push({id:round.id,type:"challenge",title:challenge.title,href:"/challenges",state:round.status==="completed"?"completed":pending>0?"pending":closed?"closed":"active",approved:Number(round.progress_value),pending,target:Number(challenge.target_value),unit:challenge.target_unit,points:challenge.reward_points,day:null,note:latest?.verification_status==="rejected"?latest.reviewer_note:null});
  }
  return {status:"ready",data:result};
 }catch{return {status:"error"};}
}
