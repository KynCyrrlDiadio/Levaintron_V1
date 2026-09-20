import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Wheat } from "lucide-react";
import { Link } from "wouter";

export default function NotFound() {
  return (
    <div className="min-h-screen w-full flex items-center justify-center bg-background">
      <Card className="w-full max-w-md mx-4">
        <CardContent className="pt-6 text-center">
          <Wheat className="h-12 w-12 mx-auto mb-4 text-primary opacity-50" />
          <h1 className="text-2xl font-bold mb-2" data-testid="text-404-title">Page Not Found</h1>
          <p className="text-sm text-muted-foreground mb-6">
            This crumb trail leads nowhere. Let's get you back.
          </p>
          <Link href="/">
            <Button data-testid="button-go-home">Back to Dashboard</Button>
          </Link>
        </CardContent>
      </Card>
    </div>
  );
}
