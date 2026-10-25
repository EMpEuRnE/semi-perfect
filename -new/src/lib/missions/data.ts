import "server-only";
import { bangkokDay, isRoundDay } from "@/lib/mission-rounds";

import { getSupabasePublicConfig } from "@/lib/env";
import { createClient } from "@/lib/supabase/server";

export type Mission = {
  id: string;
  title: string;
  description: string;
  mission_type: string;
  activity_type: string;
  target_value: number;
  target_unit: string;
  points: number;
  requires_evidence: boolean;
  status: string;
  starts_at: string | null;
  ends_at: string | null;
  created_at: string;
  recurrence: "once" | "daily";
  difficulty: "easy" | "medium" | "hard";
  participation_terms: string;
  allowed_activity_types: string[] | null;
};

export type UserMission = {
  id: string;
  mission_id: string;
  user_id: string;
  status: "joined" | "in_progress" | "completed" | "cancelled" | "expired";
  progress_value: number;
  joined_at: string;
  completed_at: string | null;
  participation_date: string | null;
  mission_snapshot: Mission | null;
  reported_value?: number;
  pending_value?: number;
  last_status?: string | null;
};

export type MissionActivity = {
  id: string;
  user_mission_id: string;
  activity_type: string;
  value: number;
  unit: string;
  evidence_url: string | null;
  evidence_notes: string | null;
  verification_status: "pending" | "approved" | "rejected";
  reviewer_note: string | null;
  created_at: string;
};

export type PointTransaction = {
  id: string;
  amount: number;
  transaction_type: string;
  source: string;
  description: string;
  created_at: string;
};

export type QueryState<T> =
  | { status: "ready"; data: T }
  | { status: "setup" }
  | { status: "error" };

const missionFields =
  "id,title,description,mission_type,activity_type,target_value,target_unit,points,requires_evidence,status,starts_at,ends_at,created_at,recurrence,difficulty,participation_terms,allowed_activity_types";
const roundFields = "id,mission_id,user_id,status,progress_value,joined_at,completed_at,participation_date,mission_snapshot";
function roundMission(mission: Mission, round: UserMission | null): Mission {
 return round?.mission_snapshot ? { ...mission, ...round.mission_snapshot, id: mission.id } : mission;
}

export async function getAvailableMissions(userId: string | null): Promise<QueryState<Array<Mission & { participation: UserMission | null }>>> {
  if (!getSupabasePublicConfig()) return { status: "setup" };

  try {
    const supabase = await createClient();
    const { data: missionRows, error: missionError } = await supabase
      .from("missions")
      .select(missionFields)
      .eq("status", "active")
      .order("created_at", { ascending: false });

    if (missionError) return { status: "error" };
    const now = Date.now();
    const missions = ((missionRows ?? []) as unknown as Mission[]).filter(m => (!m.starts_at || new Date(m.starts_at).getTime() <= now) && (!m.ends_at || new Date(m.ends_at).getTime() > now));
    const missionIds = missions.map((mission) => mission.id);
    const participationByMission = new Map<string, UserMission>();

    if (userId && missionIds.length > 0) {
      const { data: participationRows, error: participationError } = await supabase
        .from("user_missions")
        .select(roundFields)
        .eq("user_id", userId)
        .in("mission_id", missionIds)
        .or(`participation_date.is.null,participation_date.eq.${bangkokDay()}`);

      if (participationError) return { status: "error" };
      const rows = (participationRows ?? []) as unknown as UserMission[];
      const roundIds = rows.map(r => r.id);
      const totals = roundIds.length ? await supabase.from("mission_activity_totals").select("user_mission_id,reported_value,pending_value,last_status").in("user_mission_id", roundIds) : { data: [], error: null };
      if (totals.error) return { status: "error" };
      for (const row of rows) {
        const total = totals.data?.find(t => t.user_mission_id === row.id);
        participationByMission.set(row.mission_id, { ...row, reported_value: Number(total?.reported_value ?? 0), pending_value: Number(total?.pending_value ?? 0), last_status: total?.last_status ?? null });
      }
    }

    return {
      status: "ready",
      data: missions.map((mission) => ({
        ...roundMission(mission, participationByMission.get(mission.id) ?? null),
        participation: participationByMission.get(mission.id) ?? null,
      })),
    };
  } catch {
    return { status: "error" };
  }
}

export async function getMissionDetail(
  missionId: string,
  userId: string | null,
  requestedDay?: string,
): Promise<QueryState<{
  mission: Mission;
  participation: UserMission | null;
  activities: MissionActivity[];
  roundDay: string | null;
  today: string;
} | null>> {
  if (!getSupabasePublicConfig()) return { status: "setup" };

  try {
    const supabase = await createClient();
    const { data: missionRow, error: missionError } = await supabase
      .from("missions")
      .select(missionFields)
      .eq("id", missionId)
      .maybeSingle();

    if (missionError) return { status: "error" };
    if (!missionRow) return { status: "ready", data: null };

    const mission = missionRow as unknown as Mission;
    const today = bangkokDay();
    const roundDay = mission.recurrence === "daily" ? requestedDay ?? today : null;
    if (roundDay && (!isRoundDay(roundDay) || roundDay > today)) return { status: "ready", data: null };
    let participation: UserMission | null = null;
    let activities: MissionActivity[] = [];

    if (userId) {
      const roundQuery = supabase.from("user_missions").select(roundFields).eq("mission_id", missionId).eq("user_id", userId);
      const { data: participationRow, error: participationError } = await (roundDay ? roundQuery.eq("participation_date", roundDay) : roundQuery.is("participation_date", null)).maybeSingle();

      if (participationError) return { status: "error" };
      participation = (participationRow as unknown as UserMission | null) ?? null;

      if (participation) {
        const { data: activityRows, error: activityError } = await supabase
          .from("activities")
          .select("id,user_mission_id,activity_type,value,unit,evidence_url,evidence_notes,verification_status,reviewer_note,created_at")
          .eq("user_mission_id", participation.id)
          .eq("user_id", userId)
          .order("created_at", { ascending: false });

        if (activityError) return { status: "error" };
        activities = (activityRows ?? []) as unknown as MissionActivity[];
        const totals = await supabase.from("mission_activity_totals").select("reported_value,pending_value,last_status").eq("user_mission_id", participation.id).maybeSingle();
        if (totals.error) return { status: "error" };
        participation = { ...participation, reported_value: Number(totals.data?.reported_value ?? 0), pending_value: Number(totals.data?.pending_value ?? 0), last_status: totals.data?.last_status ?? null };
      }
    }

    if (roundDay && roundDay !== today && !participation) return { status: "ready", data: null };
    return { status: "ready", data: { mission: roundMission(mission, participation), participation, activities, roundDay, today } };
  } catch {
    return { status: "error" };
  }
}

export async function getWalletData(userId: string): Promise<QueryState<{
  balance: number;
  earned: number;
  spent: number;
  transactions: PointTransaction[];
}>> {
  if (!getSupabasePublicConfig()) return { status: "setup" };

  try {
    const supabase = await createClient();
    const [balanceResult, transactionResult] = await Promise.all([
      supabase
        .from("user_point_balances")
        .select("balance")
        .eq("user_id", userId)
        .maybeSingle(),
      supabase
        .from("point_transactions")
        .select("id,amount,transaction_type,source,description,created_at")
        .eq("user_id", userId)
        .order("created_at", { ascending: false }),
    ]);

    if (balanceResult.error || transactionResult.error) return { status: "error" };
    const transactions = (transactionResult.data ?? []) as unknown as PointTransaction[];
    const balanceRow = balanceResult.data as { balance: number | string } | null;

    return {
      status: "ready",
      data: {
        balance: Number(balanceRow?.balance ?? 0),
        earned: transactions.reduce((total, entry) => total + Math.max(0, Number(entry.amount)), 0),
        spent: transactions.reduce((total, entry) => total + Math.max(0, -Number(entry.amount)), 0),
        transactions: transactions.slice(0, 10),
      },
    };
  } catch {
    return { status: "error" };
  }
}

export async function getHistoryData(userId: string): Promise<QueryState<{
  missions: Array<UserMission & { missionTitle: string }>;
  activities: Array<MissionActivity & { missionTitle: string }>;
  transactions: PointTransaction[];
}>> {
  if (!getSupabasePublicConfig()) return { status: "setup" };

  try {
    const supabase = await createClient();
    const [participationResult, activityResult, transactionResult] = await Promise.all([
      supabase
        .from("user_missions")
        .select(roundFields)
        .eq("user_id", userId)
        .order("joined_at", { ascending: false })
        .limit(50),
      supabase
        .from("activities")
        .select("id,user_mission_id,activity_type,value,unit,evidence_url,evidence_notes,verification_status,reviewer_note,created_at")
        .eq("user_id", userId)
        .not("user_mission_id", "is", null)
        .order("created_at", { ascending: false })
        .limit(50),
      supabase
        .from("point_transactions")
        .select("id,amount,transaction_type,source,description,created_at")
        .eq("user_id", userId)
        .order("created_at", { ascending: false })
        .limit(50),
    ]);

    if (participationResult.error || activityResult.error || transactionResult.error) {
      return { status: "error" };
    }

    const participations = (participationResult.data ?? []) as unknown as UserMission[];
    const activities = (activityResult.data ?? []) as unknown as MissionActivity[];
    const missionIds = [...new Set(participations.map((item) => item.mission_id))];
    const titleByMission = new Map<string, string>();

    if (missionIds.length > 0) {
      const { data: missionRows, error: missionError } = await supabase
        .from("missions")
        .select("id,title")
        .in("id", missionIds);
      if (missionError) return { status: "error" };
      for (const row of (missionRows ?? []) as Array<{ id: string; title: string }>) {
        titleByMission.set(row.id, row.title);
      }
    }

    const roundById = new Map(participations.map(round => [round.id, round]));
    const missionIdByParticipation = new Map(
      participations.map((participation) => [participation.id, participation.mission_id]),
    );

    return {
      status: "ready",
      data: {
        missions: participations.map((participation) => ({
          ...participation,
          missionTitle: participation.mission_snapshot?.title ?? titleByMission.get(participation.mission_id) ?? "ภารกิจที่ถูกเก็บถาวร",
        })),
        activities: activities.map((activity) => ({
          ...activity,
          missionTitle: roundById.get(activity.user_mission_id)?.mission_snapshot?.title ?? titleByMission.get(missionIdByParticipation.get(activity.user_mission_id) ?? "")
            ?? "ภารกิจที่ถูกเก็บถาวร",
        })),
        transactions: (transactionResult.data ?? []) as unknown as PointTransaction[],
      },
    };
  } catch {
    return { status: "error" };
  }
}
